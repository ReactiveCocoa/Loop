import UIKit
import SwiftUI

class SceneDelegate: NSObject, UIWindowSceneDelegate {
    lazy var window: UIWindow? = UIWindow()

    func scene(_ scene: UIScene, willConnectTo session: UISceneSession, options connectionOptions: UIScene.ConnectionOptions) {
        let scene = scene as! UIWindowScene

        window!.rootViewController = UIHostingController(rootView: RootView())
        window!.windowScene = scene
        window!.makeKeyAndVisible()
    }
}
