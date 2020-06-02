import SwiftUI
import Loop

struct SwiftUIBasicBindingHomeView: View {
    var body: some View {
        ScrollView {
            CardNavigationLink(label: "@LoopBinding", color: .orange) {
                LoopBindingExampleView(state: simpleCounterStore.binding)
            }

            CardNavigationLink(label: "@EnvironmentLoop", color: .orange) {
                EnvironmentLoopExampleView(loop: simpleCounterStore)
            }
            
            CardNavigationLink(label: "Cats", color: .orange) {
                Breeds.makeCatsView()
            }
        }
    }
}
