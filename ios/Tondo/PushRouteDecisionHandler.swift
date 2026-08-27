import HotwireNative
import UIKit
import UserNotifications

/// The push opt-in's entry door (story 0010). Matches the invitation link on
/// `/you`; a plain GET intercepted before it ever becomes a request — the
/// same idiom as `AuthRouteDecisionHandler`, and for the same reason: a
/// `VisitProposal` is what this hooks into, and a form submit would not be
/// one.
///
///     tap ──▶ /you/push/enable      (matched here, navigation cancelled)
///              │
///              ├─ .denied  ──▶ UIApplication.openSettingsURLString
///              │
///              └─ else ──▶ requestAuthorization
///                            └─ granted ──▶ enrollPending = true
///                                            registerForRemoteNotifications()
///                                              └─ AppDelegate's
///                                                 didRegisterForRemoteNotificationsWithDeviceToken
///                                                 reads the flag, POSTs
///                                                 mode=enroll, reloads /you
///
/// ORDER MATTERS, same reason as the auth handler's own doc comment: this
/// must be registered AHEAD of `AppNavigationRouteDecisionHandler`, whose
/// `matches` is a bare same-host test and would otherwise claim this path
/// first-match-wins.
final class PushRouteDecisionHandler: NSObject, RouteDecisionHandler {
    let name = "push"

    func matches(proposal: VisitProposal, configuration: Navigator.Configuration) -> Bool {
        proposal.url.host() == configuration.startLocation.host()
            && proposal.url.path == "/you/push/enable"
    }

    func handle(proposal: VisitProposal,
                configuration: Navigator.Configuration,
                navigator: Navigating) -> Router.Decision {
        UNUserNotificationCenter.current().getNotificationSettings { settings in
            if settings.authorizationStatus == .denied {
                DispatchQueue.main.async {
                    guard let url = URL(string: UIApplication.openSettingsURLString) else { return }
                    UIApplication.shared.open(url)
                }
                return
            }

            // `.authorized` or `.notDetermined` both route here.
            // `requestAuthorization` on an already-authorized reader is a
            // harmless no-op — it calls back `granted: true` with no new
            // dialog — so this covers both without a second branch.
            UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound]) { granted, _ in
                guard granted else { return }

                // `requestAuthorization`'s completion is not guaranteed to
                // land on the main thread, and `registerForRemoteNotifications`
                // is main-thread-only (outside voice #12).
                DispatchQueue.main.async {
                    PushRegistration.enrollPending = true
                    UIApplication.shared.registerForRemoteNotifications()
                }
            }
        }

        return .cancel
    }
}
