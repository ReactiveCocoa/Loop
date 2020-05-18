import SwiftUI
import Loop

struct LoopBindingExampleView: View {
    @LoopBinding<Int, Int> var state: Int

    init(state: LoopBinding<Int, Int>) {
        _state = state
    }

    var body: some View {
        SimpleCounterView(binding: $state)
            .navigationBarTitle("@LoopBinding")
    }
}

struct LoopBindingExampleView_Previews: PreviewProvider {
    static var previews: some View {
        NavigationView {
            LoopBindingExampleView(state: simpleCounterStore.binding)
        }
    }
}
