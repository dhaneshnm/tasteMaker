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

        // The device key rides ahead of the first navigation (story 0015):
        // register → cookie into the web view's store → route. On failure the
        // shell routes anyway — the reader gets the public landing page, the
        // sign-in fragment stays empty for this user agent, and the next
        // foreground retries. The launch screen covers the round-trip.
        DeviceIdentity.register { [weak self, navigator] in
            self?.started = true
            navigator.start()
        }
    }

    func sceneDidBecomeActive(_ scene: UIScene) {
        // The retry path — but only while unhealed. Idempotent server-side
        // (same UUID → same identity), and once this process holds a 204 there
        // is nothing left to heal until the next cold launch, so a healthy
        // foreground spends no network round-trip here.
        guard started, !DeviceIdentity.registered else { return }
        DeviceIdentity.register {}
    }

    // `sceneDidBecomeActive` also fires right after launch, when `register`
    // may still be in flight — this keeps the two calls from racing the
    // cookie store on cold start.
    private var started = false
}
