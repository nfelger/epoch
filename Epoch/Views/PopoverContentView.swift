import SwiftUI

struct PopoverContentView: View {
    @Bindable var model: TimerModel

    var body: some View {
        ArcDialView(model: model)
            .frame(width: 142, height: 142)
            .padding(16)
    }
}
