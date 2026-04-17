import SwiftUI

struct ArcDialView: View {
    @Bindable var model: TimerModel
    var isOverlayMode: Bool = false
    @State private var cumulativeAngle: Double = 0
    @State private var lastAngle: Double = 0
    @State private var isDragging = false

    private var rawSeconds: Double {
        (cumulativeAngle / (2 * .pi)) * 3600
    }

    private var roundedDuration: Double {
        (rawSeconds / 60).rounded() * 60
    }

    private var arcAngle: Double {
        switch model.state {
        case .inactive:
            return cumulativeAngle
        case .running:
            if isDragging {
                return cumulativeAngle
            }
            return (model.remaining / 3600) * 2 * .pi
        case .finished:
            return 0
        }
    }

    private func arcRadius(in size: CGSize) -> CGFloat {
        min(size.width, size.height) / 2 - 15
    }

    private let arcLineWidth: CGFloat = 10

    var body: some View {
        GeometryReader { geo in
            ZStack {
                Canvas { context, size in
                    drawArc(context: context, size: size)
                }

                centerLabel(geo: geo)
            }
            .contentShape(
                isOverlayMode
                    ? AnyShape(ArcRingShape(radius: arcRadius(in: geo.size), lineWidth: arcLineWidth))
                    : AnyShape(Rectangle())
            )
            .gesture(
                DragGesture(minimumDistance: 0, coordinateSpace: .local)
                    .onChanged { value in
                        handleDragChanged(value, in: geo.size)
                    }
                    .onEnded { value in
                        handleDragEnded(value)
                    }
            )
        }
        .aspectRatio(1, contentMode: .fit)
        .onHover { hovering in
            if hovering {
                NSCursor.pointingHand.push()
            } else {
                NSCursor.pop()
            }
        }
    }

    // MARK: - Drag Handling

    private func handleDragChanged(_ value: DragGesture.Value, in size: CGSize) {
        let center = CGPoint(x: size.width / 2, y: size.height / 2)
        let deltaX = value.location.x - center.x
        let deltaY = value.location.y - center.y
        var angle = atan2(deltaX, -deltaY)
        if angle < 0 { angle += 2 * .pi }

        if isDragging {
            var delta = angle - lastAngle
            if delta > .pi { delta -= 2 * .pi }
            if delta < -.pi { delta += 2 * .pi }
            cumulativeAngle = max(0, cumulativeAngle + delta)
        } else {
            isDragging = true
            if model.state == .finished {
                model.cancel()
            } else if model.state == .running {
                cumulativeAngle = (model.remaining / 3600) * 2 * .pi
            }
        }
        lastAngle = angle

        if model.state == .running {
            model.adjustRemaining(to: roundedDuration)
        }
    }

    private func handleDragEnded(_ value: DragGesture.Value) {
        isDragging = false
        if model.state == .inactive {
            if roundedDuration >= 60 {
                cumulativeAngle = (roundedDuration / 3600) * 2 * .pi
                model.start(duration: roundedDuration)
            } else {
                cumulativeAngle = 0
            }
        }
    }

    // MARK: - Canvas Drawing

    private func drawTickMarks(
        context: GraphicsContext, center: CGPoint, radius: CGFloat
    ) {
        for idx in 0 ..< 12 {
            let tickAngle = Angle.degrees(-90 + Double(idx) * 30).radians
            let innerR = radius - arcLineWidth / 2 - 1
            let outerR = radius + arcLineWidth / 2 + 1
            var tick = Path()
            tick.move(to: CGPoint(x: center.x + innerR * CoreGraphics.cos(tickAngle),
                                  y: center.y + innerR * CoreGraphics.sin(tickAngle)))
            tick.addLine(to: CGPoint(x: center.x + outerR * CoreGraphics.cos(tickAngle),
                                     y: center.y + outerR * CoreGraphics.sin(tickAngle)))
            context.stroke(tick,
                           with: .color(.secondary.opacity(0.4)),
                           style: StrokeStyle(lineWidth: 2, lineCap: .butt))
        }
    }

    private func knobPath(
        center: CGPoint, radius: CGFloat, angleDeg: Double, diameter: CGFloat
    ) -> Path {
        let rad = Angle.degrees(angleDeg).radians
        let point = CGPoint(x: center.x + radius * CoreGraphics.cos(rad),
                            y: center.y + radius * CoreGraphics.sin(rad))
        return Path(ellipseIn: CGRect(x: point.x - diameter / 2, y: point.y - diameter / 2,
                                      width: diameter, height: diameter))
    }

    private func drawArc(context: GraphicsContext, size: CGSize) {
        let center = CGPoint(x: size.width / 2, y: size.height / 2)
        let radius = arcRadius(in: size)
        let startAngle = Angle.degrees(-90)
        let strokeStyle = StrokeStyle(lineWidth: arcLineWidth, lineCap: .butt)

        // Track ring
        var track = Path()
        track.addArc(center: center, radius: radius,
                     startAngle: startAngle, endAngle: .degrees(270), clockwise: false)
        context.stroke(track,
                       with: .color(.secondary.opacity(0.2)),
                       style: strokeStyle)

        drawTickMarks(context: context, center: center, radius: radius)

        let totalAngle = arcAngle
        guard totalAngle > 0 else {
            context.fill(knobPath(center: center, radius: radius, angleDeg: -90, diameter: 14),
                         with: .color(.white))
            return
        }

        let fullRevolutions = Int(totalAngle / (2 * .pi))
        let partialAngle = totalAngle.truncatingRemainder(dividingBy: 2 * .pi)

        for rev in 0 ..< fullRevolutions {
            let color = revolutionColor(revolution: rev)
            var fullArc = Path()
            fullArc.addArc(center: center, radius: radius,
                           startAngle: startAngle, endAngle: .degrees(270), clockwise: false)
            context.stroke(fullArc, with: .color(color.opacity(0.7)), style: strokeStyle)
        }

        if partialAngle > 0 {
            let sweepDeg = partialAngle / (2 * .pi) * 360
            let color = revolutionColor(revolution: fullRevolutions)
            var arc = Path()
            arc.addArc(center: center, radius: radius,
                       startAngle: startAngle,
                       endAngle: .degrees(-90 + sweepDeg),
                       clockwise: false)
            context.stroke(arc, with: .color(color.opacity(0.7)), style: strokeStyle)
        }

        let endSweepDeg = partialAngle > 0 ? partialAngle / (2 * .pi) * 360 : 360
        let knobSize: CGFloat = isDragging ? 16 : 14
        context.fill(knobPath(center: center, radius: radius,
                              angleDeg: -90 + endSweepDeg, diameter: knobSize),
                     with: .color(.white))
    }

    /// Color for each revolution layer: muted blue → rose → mauve → purple over 4 hours
    private func revolutionColor(revolution: Int) -> Color {
        switch revolution {
        case 0: Color(red: 0.30, green: 0.50, blue: 0.82) // cornflower blue
        case 1: Color(red: 0.82, green: 0.50, blue: 0.50) // soft rose
        case 2: Color(red: 0.75, green: 0.42, blue: 0.75) // orchid
        default: Color(red: 0.50, green: 0.38, blue: 0.72) // muted purple
        }
    }

    // MARK: - Center Label

    @ViewBuilder
    private func centerLabel(geo: GeometryProxy) -> some View {
        let duration = roundedDuration
        let effectiveRemaining = model.state == .running ? model.remaining : duration
        let totalMin = Int(effectiveRemaining) / 60
        let totalSec = Int(effectiveRemaining) % 60

        VStack(spacing: 2) {
            if model.state == .inactive, cumulativeAngle == 0, !isDragging {
                Text("Drag to set")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } else {
                if duration >= 60 || model.state == .running {
                    Text(endTimeLabel)
                        .font(.caption2)
                        .foregroundStyle(.blue)
                }
                if totalMin >= 60 {
                    Text("\(totalMin / 60)h \(totalMin % 60)m")
                        .font(.title2.bold())
                } else if totalMin > 0 {
                    Text("\(totalMin)m")
                        .font(.title2.bold())
                }
                if model.state == .running {
                    Text("\(totalSec)s")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }
        }
    }

    private var endTimeLabel: String {
        if let end = model.endDate {
            return formatTime(end)
        }
        guard roundedDuration >= 60 else { return "" }
        return formatTime(Date.now.addingTimeInterval(roundedDuration))
    }

    private static let timeFormatter: DateFormatter = {
        let fmt = DateFormatter()
        fmt.timeStyle = .short
        fmt.dateStyle = .none
        return fmt
    }()

    private func formatTime(_ date: Date) -> String {
        Self.timeFormatter.string(from: date)
    }
}

private struct ArcRingShape: Shape {
    let radius: CGFloat
    let lineWidth: CGFloat
    let tolerance: CGFloat = 7

    func path(in rect: CGRect) -> Path {
        let center = CGPoint(x: rect.midX, y: rect.midY)
        let outer = radius + lineWidth / 2 + tolerance
        let inner = max(0, radius - lineWidth / 2 - tolerance)
        var path = Path()
        path.addEllipse(in: CGRect(
            x: center.x - outer, y: center.y - outer,
            width: outer * 2, height: outer * 2
        ))
        path.addEllipse(in: CGRect(
            x: center.x - inner, y: center.y - inner,
            width: inner * 2, height: inner * 2
        ))
        return path
    }
}
