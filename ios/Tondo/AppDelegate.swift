import HotwireNative
import UIKit
import WebKit

@main
final class AppDelegate: UIResponder, UIApplicationDelegate {
    func application(_ application: UIApplication,
                     didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
        configureHotwire()
        return true
    }

    func application(_ application: UIApplication,
                     configurationForConnecting session: UISceneSession,
                     options: UIScene.ConnectionOptions) -> UISceneConfiguration {
        UISceneConfiguration(name: "Default Configuration", sessionRole: session.role)
    }

    private func configureHotwire() {
        // Every native surface the library would otherwise draw in its own
        // idiom, pointed back at the product's. See decisions/0006.
        Hotwire.config.defaultNavigationController = { LinenNavigationController() }
        Hotwire.config.defaultViewController = { LinenWebViewController(url: $0) }
        Hotwire.config.makeCustomErrorView = { LinenErrorView(error: $0, handler: $1) }

        Hotwire.config.applicationUserAgentPrefix = "Tondo iOS;"

        // The only reason to touch the web view configuration in this story.
        // `Hotwire.config.makeWebView()` calls this and then initialises the
        // bridge if any components are registered — none are — so returning a
        // plain web view here loses nothing.
        Hotwire.config.makeCustomWebView = { configuration in
            configuration.userContentController.addUserScript(DynamicType.userScript())
            return WKWebView(frame: .zero, configuration: configuration)
        }

        // Order matters: first match wins. Ours replaces the library's Safari
        // handler in the same slot, between app navigation and the system's
        // fallback for tel:/mailto:.
        Hotwire.registerRouteDecisionHandlers([
            AppNavigationRouteDecisionHandler(),
            LinenSafariRouteDecisionHandler(),
            SystemNavigationRouteDecisionHandler()
        ])

        // Bundled first, server second — and the order is the whole design.
        // `.file` resolves synchronously, so a cold launch with no network
        // still routes correctly; `.server` resolves afterwards and wins, which
        // is what lets navigation rules change without an App Store review.
        //
        // `test/integration/path_configuration_test.rb` fails if the two drift.
        Hotwire.loadPathConfiguration(from: [
            .file(Bundle.main.url(forResource: "path-configuration", withExtension: "json")!),
            .server(Endpoint.pathConfigurationURL)
        ])
    }
}
