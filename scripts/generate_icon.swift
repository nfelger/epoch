#!/usr/bin/env swift
import AppKit

// Apple macOS icon grid: 1024x1024 canvas, 824x824 squircle shape, 100px gutter
let canvasSize = 1024
let s = CGFloat(canvasSize)
let shapeSize: CGFloat = 824
let gutter: CGFloat = (s - shapeSize) / 2 // 100px
let cornerRadius: CGFloat = 185

// Arc proportions scaled to fit within the squircle shape
let center = CGPoint(x: s / 2, y: s / 2)
let arcRadius: CGFloat = 290
let strokeWidth: CGFloat = 64

let colorSpace = CGColorSpace(name: CGColorSpace.sRGB)!
guard let ctx = CGContext(
    data: nil,
    width: canvasSize,
    height: canvasSize,
    bitsPerComponent: 8,
    bytesPerRow: 0,
    space: colorSpace,
    bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
) else {
    fatalError("Failed to create bitmap context")
}

// Squircle clipping path (continuous corner approximation via standard rounded rect)
let shapeRect = CGRect(x: gutter, y: gutter, width: shapeSize, height: shapeSize)
let squirclePath = CGPath(roundedRect: shapeRect, cornerWidth: cornerRadius, cornerHeight: cornerRadius, transform: nil)
ctx.addPath(squirclePath)
ctx.clip()

// Background gradient (top-lit per Apple HIG: lighter at top, darker at bottom)
// CG origin is bottom-left, so startPoint is bottom, endPoint is top
let gradientColors = [
    CGColor(srgbRed: 0.11, green: 0.11, blue: 0.118, alpha: 1), // bottom: #1C1C1E
    CGColor(srgbRed: 0.18, green: 0.18, blue: 0.19, alpha: 1),  // top: #2E2E30
] as CFArray
guard let gradient = CGGradient(colorsSpace: colorSpace, colors: gradientColors, locations: [0, 1]) else {
    fatalError("Failed to create gradient")
}
ctx.drawLinearGradient(gradient,
                       start: CGPoint(x: s / 2, y: gutter),
                       end: CGPoint(x: s / 2, y: gutter + shapeSize),
                       options: [])

// Background track ring (full circle, subtle)
ctx.setStrokeColor(CGColor(srgbRed: 1, green: 1, blue: 1, alpha: 0.12))
ctx.setLineWidth(strokeWidth)
ctx.setLineCap(.round)
ctx.addEllipse(in: CGRect(
    x: center.x - arcRadius, y: center.y - arcRadius,
    width: arcRadius * 2, height: arcRadius * 2
))
ctx.strokePath()

// Active arc: 270° sweep from 12 o'clock clockwise to 9 o'clock
// CoreGraphics on macOS (Y-up): π/2 = top, clockwise sweeps right→bottom→left
ctx.setStrokeColor(CGColor(srgbRed: 1, green: 1, blue: 1, alpha: 1))
ctx.setLineWidth(strokeWidth)
ctx.setLineCap(.round)
ctx.addArc(center: center, radius: arcRadius,
           startAngle: .pi / 2, endAngle: .pi, clockwise: true)
ctx.strokePath()

// Save as PNG
guard let image = ctx.makeImage() else {
    fatalError("Failed to create image")
}

let outputPath = CommandLine.arguments.count > 1
    ? CommandLine.arguments[1]
    : "icon_512x512@2x.png"
let url = URL(fileURLWithPath: outputPath)

let rep = NSBitmapImageRep(cgImage: image)
guard let pngData = rep.representation(using: .png, properties: [:]) else {
    fatalError("Failed to encode PNG")
}
try! pngData.write(to: url)
print("Generated \(url.lastPathComponent) (\(canvasSize)x\(canvasSize))")
