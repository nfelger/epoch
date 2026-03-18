import SwiftUI

struct PopoverContentView: View {
    @Bindable var model: TimerModel

    var body: some View {
        VStack(spacing: 12) {
            ArcDialView(model: model)
                .frame(width: 190, height: 190)

            if model.state == .running {
                Button("Cancel") {
                    model.cancel()
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
            }
        }
        .padding(.horizontal, 20)
        .padding(.top, 16)
        .padding(.bottom, 16)
        .frame(width: 230)
    }
}
