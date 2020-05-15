import SwiftUI

struct UIViewControllerView<VC: UIViewController>: UIViewControllerRepresentable {
    typealias UIViewControllerType = VC

    let factory: () -> VC

    init(_ factory: @escaping () -> VC) {
        self.factory = factory
    }

    func makeUIViewController(context: Context) -> VC {
        factory()
    }

    func updateUIViewController(_ uiViewController: VC, context: Context) {}
}
