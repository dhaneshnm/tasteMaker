import AuthenticationServices
import HotwireNative
import UIKit

/// Sign-in, in the only container Google will accept (story 0017 Release 2).
///
/// Google answers an embedded web view with `403 disallowed_useragent`, by
/// policy, so OAuth cannot happen in the shell's `WKWebView`. Apple's answer is
/// `ASWebAuthenticationSession`: a Safari-backed sheet the system owns.
///
/// The catch is that the sheet has its OWN cookie jar and there is no API to
/// share it. So the session established in there is invisible to the web view
/// the reader comes back to. What crosses is a token:
///
///     tap  ──> /auth/start/:provider          (matched here, navigation cancelled)
///              │
///              └─ ASWebAuthenticationSession opens it in Safari's container
///                    the page submits itself into OmniAuth's POST-only door
///                    provider consent
///                    /auth/:provider/callback   ← Safari's jar
///                    302 tondo://auth?handoff=<token>
///              │
///     shell ──┴─> WKWebView loads /session/handoff?token=<token>
///                    server spends the token, writes the session HERE,
///                    claims this device's kept works, and redirects
///
/// WHY A ROUTE DECISION HANDLER AND NOT A BRIDGE COMPONENT. `CLAUDE.md` allows
/// bridge components "only where genuinely required", and this is not one of
/// those places: the shell already registers a custom handler
/// (`LinenSafariRouteDecisionHandler`), the mechanism is "match a URL, do
/// something native, cancel" — exactly this — and a handler needs no Stimulus
/// controller, no `@hotwired/hotwire-native-bridge` pin, and no change to
/// `makeCustomWebView`. It also decides the server's markup: `/you` renders the
/// doors as LINKS for a native reader, because a form submit is not a
/// `VisitProposal` and would sail straight past this into the web view.
///
/// ORDER MATTERS. This must be registered ahead of
/// `LinenSafariRouteDecisionHandler`, whose `matches` is a bare off-host test
/// and would otherwise take `/auth/start` first once the server redirected.
final class AuthRouteDecisionHandler: NSObject, RouteDecisionHandler {
    let name = "auth"

    /// The scheme the callback comes home on. Declared in `Info.plist` under
    /// `CFBundleURLTypes`; `ASWebAuthenticationSession` refuses a callback whose
    /// scheme the app has not claimed.
    static let callbackScheme = "tondo"

    /// Held for the lifetime of the sheet. `ASWebAuthenticationSession` is
    /// deallocated — and silently cancelled — if nothing retains it.
    private var session: ASWebAuthenticationSession?

    func matches(proposal: VisitProposal, configuration: Navigator.Configuration) -> Bool {
        proposal.url.host() == configuration.startLocation.host()
            && proposal.url.path.hasPrefix("/auth/start/")
    }

    func handle(proposal: VisitProposal,
                configuration: Navigator.Configuration,
                navigator: Navigating) -> Router.Decision {
        let presenter = navigator.activeNavigationController

        let session = ASWebAuthenticationSession(
            url: proposal.url,
            callbackURLScheme: Self.callbackScheme
        ) { [weak self] callbackURL, error in
            self?.session = nil

            // A cancelled sheet is not an error. The reader tapped Cancel or
            // swiped down; they are still the device they were, and the corner
            // they started on is already on screen behind the sheet. Saying
            // anything here would be the app apologising for a decision.
            guard error == nil, let callbackURL else { return }

            guard let token = URLComponents(url: callbackURL, resolvingAgainstBaseURL: false)?
                .queryItems?.first(where: { $0.name == "handoff" })?.value else { return }

            // Back into the web view's own jar. The server spends the token,
            // writes the session, claims whatever this device was holding, and
            // decides where to land — the collection when works actually moved,
            // the corner when none did.
            var handoff = URLComponents(
                url: Endpoint.url.appendingPathComponent("session/handoff"),
                resolvingAgainstBaseURL: false
            )
            handoff?.queryItems = [ URLQueryItem(name: "token", value: token) ]

            guard let destination = handoff?.url else { return }

            Task { @MainActor in
                // The completion handler fires the instant the callback URL is
                // intercepted — before the sheet's own dismissal transition has
                // finished animating off screen (widely reported against
                // ASWebAuthenticationSession; not fixed by `[weak self]` or by
                // clearing `self.session` above, both of which already run).
                // Routing into that transition can silently no-op: the visit
                // fires but nothing lands on screen, which reads to a reader as
                // "tapped Sign in with Apple, nothing happened" — the exact
                // shape of the Aug 31 App Review rejection. A beat lets the
                // dismissal settle first.
                try? await Task.sleep(for: .milliseconds(300))
                navigator.route(destination)
            }
        }

        session.presentationContextProvider = self
        // The reader may already be signed in to the provider in Safari. Using
        // that is the point of the shared container — an ephemeral session
        // would ask them to type a password the phone already knows.
        session.prefersEphemeralWebBrowserSession = false

        self.session = session

        Task { @MainActor in
            _ = presenter // presentation anchor comes from the provider below
            session.start()
        }

        return .cancel
    }
}

extension AuthRouteDecisionHandler: ASWebAuthenticationPresentationContextProviding {
    func presentationAnchor(for session: ASWebAuthenticationSession) -> ASPresentationAnchor {
        UIApplication.shared.connectedScenes
            .compactMap { ($0 as? UIWindowScene)?.keyWindow }
            .first ?? ASPresentationAnchor()
    }
}
