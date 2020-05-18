import SwiftUI

struct RootView: View {
    var body: some View {
        NavigationView {
            ScrollView {
                RACHeaderView()

                Spacer(minLength: 64)

                HStack {
                    Text("Examples")
                        .font(.headline)
                        .fontWeight(.semibold)
                        .foregroundColor(Color.black.opacity(0.8))
                    Spacer()
                }
                .padding([.leading, .trailing], 24)

                CardNavigationLink(label: "Unified Store + UIKit", color: .blue) {
                    UnifiedStoreUIKitHomeView()
                }

                CardNavigationLink(label: "SwiftUI: Basic Binding", color: .orange) {
                    SwiftUIBasicBindingHomeView()
                }
            }
            .navigationBarTitle("Loop Examples")
            .navigationBarHidden(true)
        }
    }
}

struct RootView_Previews: PreviewProvider {
    static var previews: some View {
        RootView()
    }
}
