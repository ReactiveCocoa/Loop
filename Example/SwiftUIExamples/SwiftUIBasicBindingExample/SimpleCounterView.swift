import SwiftUI
import Loop

struct SimpleCounterView: View {
    @LoopBinding<Int, Int> var state: Int

    init(binding: LoopBinding<Int, Int>) {
        _state = binding
    }

    var body: some View {
        VStack {
            Spacer()
                .layoutPriority(1.0)

            Button(
                action: { self.$state.send(-1) },
                label: { Image(systemName: "minus.circle") }
            )
            .padding()

            Text("\(self.state)")
                .font(.system(.largeTitle, design: .monospaced))

            Button(
                action: { self.$state.send(1) },
                label: { Image(systemName: "plus.circle") }
            )
            .padding()

            Spacer()
                .layoutPriority(1.0)
        }
    }
}
