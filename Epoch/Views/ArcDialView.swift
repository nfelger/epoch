import SwiftUI

struct ArcDialView: View {
    @Bindable var model: TimerModel
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

    var body: some View {
        GeometryReader { geo in
            ZStack {
                Canvas { context, size in
                    drawArc(context: context, size: size)
                }

                centerLabel(geo: geo)
            }
            .contentShape(Rectangle())
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
            if model.state == .running {
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
        context: GraphicsContext, center: CGPoint, radius: CGFloat, lineWidth: CGFloat
    ) {
        for idx in 0 ..< 12 {
            let tickAngle = Angle.degrees(-90 + Double(idx) * 30).radians
            let innerR = radius - lineWidth / 2
            let outerR = radius + lineWidth / 2
            var tick = Path()
            tick.move(to: CGPoint(x: center.x + innerR * CoreGraphics.cos(tickAngle),
                                  y: center.y + innerR * CoreGraphics.sin(tickAngle)))
            tick.addLine(to: CGPoint(x: center.x + outerR * CoreGraphics.cos(tickAngle),
                                     y: center.y + outerR * CoreGraphics.sin(tickAngle)))
            context.stroke(tick,
                           with: .color(.secondary.opacity(0.4)),
                           style: StrokeStyle(lineWidth: 1.5, lineCap: .butt))
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
        let radius = min(size.width, size.height) / 2 - 20
        let startAngle = Angle.degrees(-90)
        let lineWidth: CGFloat = 14
        let strokeStyle = StrokeStyle(lineWidth: lineWidth, lineCap: .round)

        // Track ring
        var track = Path()
        track.addArc(center: center, radius: radius,
                     startAngle: startAngle, endAngle: .degrees(270), clockwise: false)
        context.stroke(track,
                       with: .color(.secondary.opacity(0.2)),
                       style: strokeStyle)

        drawTickMarks(context: context, center: center, radius: radius, lineWidth: lineWidth)

        let totalAngle = arcAngle
        guard totalAngle > 0 else {
            context.fill(knobPath(center: center, radius: radius, angleDeg: -90, diameter: 18),
                         with: .color(.accentColor))
            return
        }

        let fullRevolutions = Int(totalAngle / (2 * .pi))
        let partialAngle = totalAngle.truncatingRemainder(dividingBy: 2 * .pi)

        for rev in 0 ..< fullRevolutions {
            let color = revolutionColor(revolution: rev)
            var fullArc = Path()
            fullArc.addArc(center: center, radius: radius,
                           startAngle: startAngle, endAngle: .degrees(270), clockwise: false)
            context.stroke(fullArc, with: .color(color), style: strokeStyle)
        }

        if partialAngle > 0 {
            let sweepDeg = partialAngle / (2 * .pi) * 360
            let color = revolutionColor(revolution: fullRevolutions)
            var arc = Path()
            arc.addArc(center: center, radius: radius,
                       startAngle: startAngle,
                       endAngle: .degrees(-90 + sweepDeg),
                       clockwise: false)
            context.stroke(arc, with: .color(color), style: strokeStyle)
        }

        let endSweepDeg = partialAngle > 0 ? partialAngle / (2 * .pi) * 360 : 360
        let knobSize: CGFloat = isDragging ? 22 : 18
        context.fill(knobPath(center: center, radius: radius,
                              angleDeg: -90 + endSweepDeg, diameter: knobSize),
                     with: .color(revolutionColor(revolution: fullRevolutions)))
    }

    /// Color for each revolution layer: accent → red → deep purple over 4 hours
    private func revolutionColor(revolution: Int) -> Color {
        switch revolution {
        case 0: .accentColor
        case 1: Color(red: 0.85, green: 0.25, blue: 0.3)
        case 2: Color(red: 0.7, green: 0.15, blue: 0.5)
        default: Color(red: 0.45, green: 0.1, blue: 0.6) // deep purple at 4h+
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
