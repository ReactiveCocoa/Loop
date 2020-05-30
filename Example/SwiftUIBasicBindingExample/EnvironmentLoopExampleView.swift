import SwiftUI
import Loop

struct EnvironmentLoopExampleView: View {
    let loop: Loop<Int, Int>

    init(loop: Loop<Int, Int>) {
        self.loop = loop
    }

    var body: some View {
        EnvironmentLoopContentView()
            .environmentLoop(self.loop)
            .navigationBarTitle("@EnvironmentLoop")
    }
}

private struct EnvironmentLoopContentView: View {
    @EnvironmentLoop<Int, Int> var state: Int

    var body: some View {
        SimpleCounterView(binding: $state)
    }
}

struct EnvironmentLoopExampleView_Previews: PreviewProvider {
    static var previews: some View {
        NavigationView {
            EnvironmentLoopExampleView(loop: simpleCounterStore)
        }
    }
}
