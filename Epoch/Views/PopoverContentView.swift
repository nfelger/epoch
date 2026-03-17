import SwiftUI

struct PopoverContentView: View {
    @Bindable var model: TimerModel

    var body: some View {
        VStack(spacing: 16) {
            ArcDialView(model: model)
                .frame(width: 200, height: 200)

            if model.state == .running {
                Button("Cancel") {
                    model.cancel()
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
            }
        }
        .padding(20)
        .frame(width: 240)
    }
}
