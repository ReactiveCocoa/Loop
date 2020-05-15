import SwiftUI

struct UnifiedStoreUIKitHomeView: View {
    var body: some View {
        List {
            NavigationLink(
                destination: UIViewControllerView {
                    CounterViewController(
                        store: UnifiedStore.store
                            .scoped(to: \.counter, event: UnifiedStore.Event.counter)
                    )
                }
                .edgesIgnoringSafeArea(.all)
                .navigationBarTitle("Counter"),
                label: { Text("Counter") }
            )

            NavigationLink(
                destination: UIViewControllerView {
                    MoviesViewController(
                        store: UnifiedStore.store
                            .scoped(to: \.movies, event: UnifiedStore.Event.movies)
                    )
                }
                .edgesIgnoringSafeArea(.all)
                .navigationBarTitle("Movies"),
                label: { Text("Movies") }
            )
        }
        .navigationBarTitle("Unified Store + UIKit")
    }
}
