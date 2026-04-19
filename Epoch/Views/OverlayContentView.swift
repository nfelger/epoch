import SwiftUI

struct OverlayContentView: View {
    @Bindable var model: TimerModel
    var onDragChanged: (CGSize) -> Void = { _ in }
    var onDragEnded: () -> Void = {}
    @State private var borderOpacity: Double = 0.4

    var body: some View {
        ArcDialView(model: model, isOverlayMode: true)
            .frame(width: 142, height: 142)
            .padding(16)
            .overlay(pulsingBorder)
            .background(
                Color.clear
                    .contentShape(Rectangle())
                    .gesture(
                        DragGesture(minimumDistance: 2, coordinateSpace: .local)
                            .onChanged { value in onDragChanged(value.translation) }
                            .onEnded { _ in onDragEnded() }
                    )
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
