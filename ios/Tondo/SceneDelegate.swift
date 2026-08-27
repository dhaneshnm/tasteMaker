import HotwireNative
import UIKit
import UserNotifications

final class SceneDelegate: UIResponder, UIWindowSceneDelegate {
    var window: UIWindow?

    // The scene AppDelegate reaches to route a notification tap or reload
    // after enrollment (story 0010) — the Navigator lives here, not there,
    // and `UIApplicationSupportsMultipleScenes` is false (Info.plist), so
    // there is only ever one.
    static weak var current: SceneDelegate?

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

        Self.current = self

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
        // Independent of the device-identity retry below — this must run on
        // EVERY healthy foreground too, not only while device registration
        // is unhealed (a `guard ... else { return }` sharing that condition
        // would skip it on the common path, where nothing is unhealed).
        reconcilePushAuthorization()

        // The retry path — but only while unhealed. Idempotent server-side
        // (same UUID → same identity), and once this process holds a 204 there
        // is nothing left to heal until the next cold launch, so a healthy
        // foreground spends no network round-trip here.
        guard started, !DeviceIdentity.registered else { return }
        DeviceIdentity.register {}
    }

    // Launch reconcile, both directions (story 0010, plan step 5). A local,
    // no-network read of iOS's own authorization state; only a mismatch
    // costs a round trip:
    //
    //   .authorized ──▶ registerForRemoteNotifications() — tokens rotate on
    //                    restore-from-backup, and the didRegister callback's
    //                    `mode=refresh` path (AppDelegate) is what makes this
    //                    safe against reversing a web opt-out.
    //   .denied     ──▶ POST mode=refresh, enabled=false — the reader who
    //                    killed notifications in Settings stops being lied
    //                    to by an ON toggle on /you (outside voice #8).
    //
    // Acts only when `settings.authorizationStatus` differs from the last
    // reconcile this process saw (`lastReconciledStatus`), not on every
    // foreground unconditionally (/code-review, finding 8: an authorized
    // reader who repeatedly opens/backgrounds/reopens the app was paying a
    // full network round trip — and a slice of the shared 10/minute
    // NativeEndpoint rate-limit budget — every single time, for no
    // behavioral gain over a once-per-change check). The first foreground
    // each launch always reconciles (`lastReconciledStatus` starts nil).
    private var lastReconciledStatus: UNAuthorizationStatus?

    private func reconcilePushAuthorization() {
        UNUserNotificationCenter.current().getNotificationSettings { [weak self] settings in
            let status = settings.authorizationStatus
            guard self?.lastReconciledStatus != status else { return }

            DispatchQueue.main.async {
                self?.lastReconciledStatus = status
                switch status {
                case .authorized:
                    // Skipped while a deliberate tap's own registration is
                    // still in flight (/code-review, finding 4): two
                    // concurrent `registerForRemoteNotifications()` calls
                    // race to consume `PushRegistration.enrollPending` in
                    // AppDelegate's single token callback — if this
                    // reconcile call's token lands first, the real tap's
                    // callback reads `enrollPending == false`, POSTs
                    // `mode=refresh` instead of `mode=enroll`, and /you
                    // never reloads to show the toggle turned on.
                    guard !PushRegistration.enrollPending else { return }
                    UIApplication.shared.registerForRemoteNotifications()
                case .denied:
                    PushRegistration.register(token: nil, mode: .refresh, enabled: false) {}
                default:
                    break
                }
            }
        }
    }

    // `sceneDidBecomeActive` also fires right after launch, when `register`
    // may still be in flight — this keeps the two calls from racing the
    // cookie store on cold start.
    private var started = false

    // AppDelegate's `didReceive` reaches this on a notification tap. A fresh
    // request for root, not a restored session — `Navigator.route` visits
    // like any other navigation, so this rides the same Turbo machinery
    // every in-app link does.
    func routeToRoot() {
        navigator.route(Endpoint.url)
    }

    // AppDelegate's `didRegisterForRemoteNotificationsWithDeviceToken` reaches
    // this only after the enroll POST completes, only for the deliberate
    // tap — see the callback's own comment for why healing never reloads.
    func reload() {
        navigator.reload()
    }
}
