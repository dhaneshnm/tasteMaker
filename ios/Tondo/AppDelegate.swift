import HotwireNative
import UIKit
import UserNotifications
import WebKit

@main
final class AppDelegate: UIResponder, UIApplicationDelegate {
    func application(_ application: UIApplication,
                     didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
        configureHotwire()

        // Wired, not just written (story 0010, eng review outside voice #9):
        // an unassigned delegate means `willPresent`/`didReceive` never fire
        // at all, silently, which is a worse failure than a crash.
        UNUserNotificationCenter.current().delegate = self

        return true
    }

    func application(_ application: UIApplication,
                     configurationForConnecting session: UISceneSession,
                     options: UIScene.ConnectionOptions) -> UISceneConfiguration {
        UISceneConfiguration(name: "Default Configuration", sessionRole: session.role)
    }

    // The token callback fires on EVERY successful `registerForRemoteNotifications()`
    // call — the opt-in tap AND every cold-launch healing retry
    // (`SceneDelegate.sceneDidBecomeActive`) alike. `PushRegistration.enrollPending`
    // is what tells the two apart (story 0010, eng review outside voice #10):
    // an unconditional reload here would add a daily needless POST-plus-reload
    // racing `navigator.start()` on cold launch.
    func application(_ application: UIApplication,
                     didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data) {
        let token = deviceToken.map { String(format: "%02.2hhx", $0) }.joined()
        let wasEnrolling = PushRegistration.enrollPending
        PushRegistration.enrollPending = false

        PushRegistration.register(token: token, mode: wasEnrolling ? .enroll : .refresh) {
            // Reload rides the POST's completion, never the authorization
            // grant — the page must not repaint before the server actually
            // knows. Only the deliberate tap reloads; a healing refresh is
            // invisible to the reader who never asked for anything this
            // launch.
            guard wasEnrolling else { return }
            SceneDelegate.current?.reload()
        }
    }

    func application(_ application: UIApplication,
                     didFailToRegisterForRemoteNotificationsWithError error: Error) {
        // Nothing to clean up: no token means the server was never told
        // anything happened. `enrollPending` still needs clearing so a later,
        // successful registration this launch is read as a fresh attempt.
        PushRegistration.enrollPending = false
    }

    private func configureHotwire() {
        // Every native surface the library would otherwise draw in its own
        // idiom, pointed back at the product's. See decisions/0006.
        Hotwire.config.defaultNavigationController = { LinenNavigationController() }
        Hotwire.config.defaultViewController = { LinenWebViewController(url: $0) }
        Hotwire.config.makeCustomErrorView = { LinenErrorView(error: $0, handler: $1) }

        // The version is load-bearing, not decoration. The server reads it to
        // decide whether this binary has the auth bridge behind its sign-in
        // doors — Rails deploys in seconds and binaries do not, so a shell that
        // sends no version is assumed to be one built before the transport
        // existed and is shown no doors at all. See
        // `ApplicationController#native_shell_version`.
        Hotwire.config.applicationUserAgentPrefix =
            "Tondo iOS/\(Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") ?? "1");"

        // `Hotwire.config.makeWebView()` calls this and then initialises the
        // bridge itself, automatically, because `ShareComponent` is now
        // registered below — nothing here has to call `Bridge.initialize`.
        // Returning a plain, otherwise-uncustomized web view loses nothing.
        Hotwire.config.makeCustomWebView = { configuration in
            configuration.userContentController.addUserScript(DynamicType.userScript())
            return WKWebView(frame: .zero, configuration: configuration)
        }

        // The shell's first bridge component (story 0031, `decisions/0021`).
        // Registering it is also what puts `bridge-components: [share]` on
        // every WKWebView's User-Agent (`HotwireConfig.userAgent`, read from
        // the vendored SPM source rather than assumed) — the signal both
        // `share_controller.js` and `layouts/_head.html.erb`'s reveal script
        // key on, and the reason no separate reveal call belongs here.
        Hotwire.registerBridgeComponents([ ShareComponent.self ])

        // Order matters: first match wins. Ours replaces the library's Safari
        // handler in the same slot, between app navigation and the system's
        // fallback for tel:/mailto:.
        // Order matters: first match wins. The auth and push handlers go
        // ahead of app navigation, whose `matches` is a bare same-host test
        // and would otherwise claim `/auth/start/*` or `/you/push/enable`
        // first (story 0010, eng review outside voice #11 — same trap the
        // auth handler's own doc comment records).
        Hotwire.registerRouteDecisionHandlers([
            AuthRouteDecisionHandler(),
            PushRouteDecisionHandler(),
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

extension AppDelegate: UNUserNotificationCenterDelegate {
    // A reader already looking at the art gets no banner over it — the same
    // "nothing hovers over a painting" spirit DESIGN rule 5 states for the
    // web (story 0010).
    func userNotificationCenter(_ center: UNUserNotificationCenter,
                                willPresent notification: UNNotification,
                                withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void) {
        completionHandler([])
    }

    // Story 0010, eng review outside voice #2 — the load-bearing method in
    // this whole feature. A tap on a suspended or backgrounded app (the
    // NORMAL state at noon for a daily-habit reader, not the rare cold
    // launch) is bare activation with no navigation of its own: without
    // this, the reader lands on whatever screen they left, or a cached
    // yesterday. Routes to a fresh request for root, not a restored session
    // — "tapping the knock puts the art on my screen" is this one call.
    func userNotificationCenter(_ center: UNUserNotificationCenter,
                                didReceive response: UNNotificationResponse,
                                withCompletionHandler completionHandler: @escaping () -> Void) {
        SceneDelegate.current?.routeToRoot()
        completionHandler()
    }
}
