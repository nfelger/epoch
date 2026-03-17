import SwiftUI

struct ArcDialView: View {
    @Bindable var model: TimerModel
    @State private var cumulativeAngle: Double = 0
    @State private var lastAngle: Double = 0
    @State private var isDragging = false
    @State private var snapPulse = false

    private var arcAngle: Double {
        switch model.state {
        case .inactive:
            return cumulativeAngle
        case .running:
            guard model.totalDuration > 0 else { return 0 }
            return (model.remaining / model.totalDuration) * cumulativeAngle
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
                .scaleEffect(snapPulse ? 1.03 : 1.0)
                .animation(.spring(duration: 0.12), value: snapPulse)

                centerLabel(geo: geo)
            }
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
    }

    // MARK: - Drag Handling

    private func handleDragChanged(_ value: DragGesture.Value, in size: CGSize) {
        let center = CGPoint(x: size.width / 2, y: size.height / 2)
        let dx = value.location.x - center.x
        let dy = value.location.y - center.y
        var angle = atan2(dx, -dy)
        if angle < 0 { angle += 2 * .pi }

        if isDragging {
            var delta = angle - lastAngle
            if delta > .pi  { delta -= 2 * .pi }
            if delta < -.pi { delta += 2 * .pi }
            cumulativeAngle = max(0, cumulativeAngle + delta)
            applySnap()
        } else {
            isDragging = true
        }
        lastAngle = angle

        if model.state == .running {
            let newDuration = (cumulativeAngle / (2 * .pi)) * 3600
            model.adjustRemaining(to: newDuration)
        }
    }

    private func handleDragEnded(_ value: DragGesture.Value) {
        isDragging = false
        if model.state == .inactive {
            let duration = (cumulativeAngle / (2 * .pi)) * 3600
            if duration >= 60 {
                model.start(duration: duration)
            } else {
                cumulativeAngle = 0
            }
        }
    }

    // MARK: - Snap

    private func applySnap() {
        let snapInterval: Double = .pi / 6
        let snapThreshold: Double = .pi / 36
        let nearest = round(cumulativeAngle / snapInterval) * snapInterval
        if nearest > 0 && abs(cumulativeAngle - nearest) < snapThreshold {
            cumulativeAngle = nearest
            if !snapPulse {
                snapPulse = true
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.12) {
                    snapPulse = false
                }
            }
        }
    }

    // MARK: - Canvas Drawing

    private func drawArc(context: GraphicsContext, size: CGSize) {
        let center = CGPoint(x: size.width / 2, y: size.height / 2)
        let radius = min(size.width, size.height) / 2 - 20
        let startAngle = Angle.degrees(-90)

        var track = Path()
        track.addArc(center: center, radius: radius,
                     startAngle: startAngle, endAngle: .degrees(270), clockwise: false)
        context.stroke(track,
                       with: .color(.secondary.opacity(0.2)),
                       style: StrokeStyle(lineWidth: 14, lineCap: .round))

        let sweepDeg = (arcAngle.truncatingRemainder(dividingBy: 2 * .pi)) / (2 * .pi) * 360
        guard sweepDeg > 0 else { return }

        var arc = Path()
        arc.addArc(center: center, radius: radius,
                   startAngle: startAngle,
                   endAngle: .degrees(-90 + sweepDeg),
                   clockwise: false)
        context.stroke(arc,
                       with: .color(.accentColor),
                       style: StrokeStyle(lineWidth: 14, lineCap: .round))

        let endRad = Angle.degrees(-90 + sweepDeg).radians
        let knobCenter = CGPoint(x: center.x + radius * CoreGraphics.cos(endRad),
                                 y: center.y + radius * CoreGraphics.sin(endRad))
        let knob = Path(ellipseIn: CGRect(x: knobCenter.x - 9, y: knobCenter.y - 9,
                                          width: 18, height: 18))
        context.fill(knob, with: .color(.accentColor))
    }

    // MARK: - Center Label

    @ViewBuilder
    private func centerLabel(geo: GeometryProxy) -> some View {
        let duration = (cumulativeAngle / (2 * .pi)) * 3600
        let effectiveRemaining = model.state == .running ? model.remaining : duration
        let totalMin = Int(effectiveRemaining) / 60
        let totalSec = Int(effectiveRemaining) % 60

        VStack(spacing: 2) {
            if duration >= 60 || model.state == .running {
                Text(endTimeLabel)
                    .font(.caption2)
                    .foregroundStyle(.blue)
            }
            if model.state == .running && totalMin >= 60 {
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

    private var endTimeLabel: String {
        if let end = model.endDate {
            return formatTime(end)
        }
        let d = (cumulativeAngle / (2 * .pi)) * 3600
        guard d >= 60 else { return "" }
        return formatTime(Date.now.addingTimeInterval(d))
    }

    private func formatTime(_ date: Date) -> String {
        let fmt = DateFormatter()
        fmt.timeStyle = .short
        fmt.dateStyle = .none
        return fmt.string(from: date)
    }
}
