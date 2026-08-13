import HotwireNative
import UIKit

final class SceneDelegate: UIResponder, UIWindowSceneDelegate {
    var window: UIWindow?

    private let navigator = Navigator(
        configuration: .init(name: "main", startLocation: Endpoint.url)
    )

    func scene(_ scene: UIScene,
               willConnectTo session: UISceneSession,
               options connectionOptions: UIScene.ConnectionOptions) {
        guard let windowScene = scene as? UIWindowScene else { return }

        let window = UIWindow(windowScene: windowScene)
        window.rootViewController = navigator.rootViewController

        // One skin (decisions/0003). `application.css` has no
        // `prefers-color-scheme` rule, so in iOS dark mode the page would stay
        // linen while every native surface around it flipped to black. Forcing
        // `.light` is also what makes `.darkContent` status bar glyphs resolve
        // correctly on linen — one lever, two problems.
        //
        // This does not disable Smart Invert, and it should not: that is the
        // reader's accessibility setting, not ours to opt out of.
        window.overrideUserInterfaceStyle = .light

        // Removes iOS blue from every system control in one line — selection
        // handles, alert buttons, the share sheet, and the Safari sheet's
        // controls, which read `.tintColor` from here.
        window.tintColor = .gold

        window.backgroundColor = .linen

        self.window = window
        window.makeKeyAndVisible()

        navigator.start()
    }
}
