import HotwireNative
import SafariServices
import UIKit

/// External links, in the product's colours.
///
/// The library's own `SafariViewControllerRouteDecisionHandler` already does the
/// right thing structurally — universal link first, `SFSafariViewController`
/// otherwise — and it sets `preferredControlTintColor = .tintColor`, which
/// resolves to whatever the window is tinted with. Since `SceneDelegate` tints
/// the window gold, that part is already correct.
///
/// What it does not set is `preferredBarTintColor`, so the sheet's bar arrives
/// in system white above a linen app. That class is `final`, so replacing the
/// handler is the only way to change it — which is why this file exists at all
/// rather than a one-line configuration.
///
/// It is registered ahead of the library's own handler in `AppDelegate`.
final class LinenSafariRouteDecisionHandler: RouteDecisionHandler {
    let name = "linen-safari"

    func matches(proposal: VisitProposal, configuration: Navigator.Configuration) -> Bool {
        let location = proposal.url

        // SFSafariViewController traps on anything that is not http(s).
        guard location.scheme == "http" || location.scheme == "https" else { return false }

        return configuration.startLocation.host() != location.host()
    }

    func handle(proposal: VisitProposal,
                configuration: Navigator.Configuration,
                navigator: Navigating) -> Router.Decision {
        let url = proposal.url
        let presenter = navigator.activeNavigationController

        Task { @MainActor in
            // A universal link belongs in the app that claims it — a museum's
            // own app, say — before it belongs in our sheet.
            let options = UIScene.OpenExternalURLOptions()
            options.universalLinksOnly = true

            if let scene = presenter.view.window?.windowScene,
               await scene.open(url, options: options) {
                return
            }

            let safari = SFSafariViewController(url: url)
            safari.modalPresentationStyle = .pageSheet
            safari.preferredBarTintColor = .linen
            safari.preferredControlTintColor = .gold
            safari.dismissButtonStyle = .close

            presenter.present(safari, animated: true)
        }

        return .cancel
    }
}
