import SwiftUI

struct OverlayContentView: View {
    @Bindable var model: TimerModel
    var onWindowDragChanged: () -> Void = {}
    var onWindowDragEnded: () -> Void = {}
    @State private var borderOpacity: Double = 0.4

    var body: some View {
        ArcDialView(model: model)
            .frame(width: 142, height: 142)
            .padding(16)
            .overlay(pulsingBorder)
            .contentShape(Rectangle())
            .gesture(
                DragGesture(minimumDistance: 2)
                    .onChanged { _ in onWindowDragChanged() }
                    .onEnded { _ in onWindowDragEnded() }
            )
    }

    @ViewBuilder
    private var pulsingBorder: some View {
        if model.state == .finished {
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.red, lineWidth: 3)
                .opacity(borderOpacity)
                .onAppear {
                    withAnimation(
                        .easeInOut(duration: 1.0)
                            .repeatForever(autoreverses: true)
                    ) {
                        borderOpacity = 1.0
                    }
                }
                .onDisappear {
                    borderOpacity = 0.4
                }
        }
    }
}
