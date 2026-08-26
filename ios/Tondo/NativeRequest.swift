import Foundation

/// The secret-gated POST every native endpoint call rides — shared by
/// `DeviceIdentity` (story 0015) and `PushRegistration` (story 0010), which
/// used to each build this by hand: same secret header, same explicit UA,
/// same 5s timeout, same ephemeral session, because the server's
/// `NativeEndpoint` concern gates every one of these calls identically
/// (/simplify, simplification finding — the two had drifted into near-
/// verbatim copies of each other).
enum NativeRequest {
    /// Ephemeral so the ONLY cookie jar that matters is the web view's — a
    /// per-call session leaks its queue until invalidated, for no isolation
    /// gain. The 5-second timeout is load-bearing: `DeviceIdentity`'s cold
    /// launch gates ALL UI on this round-trip, and the default 60s would
    /// leave a reader on a degraded network (captive portal, stalled TLS)
    /// staring at the launch screen for a minute before the proceed-anyway
    /// fallback fired (code review F3). Airplane mode already fails fast;
    /// this bounds everything slower.
    static let session: URLSession = {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.timeoutIntervalForRequest = 5
        return URLSession(configuration: configuration)
    }()

    /// nil when `TondoAppSecret` is missing from Info.plist — every caller
    /// treats that the same way it treats any other failure: call its own
    /// completion and proceed degraded, never block on it.
    static func build(path: String, body: String) -> URLRequest? {
        guard let secret = Bundle.main.object(forInfoDictionaryKey: "TondoAppSecret") as? String,
              !secret.isEmpty else {
            return nil
        }

        var request = URLRequest(url: Endpoint.url.appendingPathComponent(path))
        request.httpMethod = "POST"
        request.setValue(secret, forHTTPHeaderField: "X-Tondo-App")
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        // The server judges user agents (`allow_browser`), and the sign-in
        // fragment renders empty for this one — an explicit identity, not
        // whatever CFNetwork writes this year (eng review A4).
        request.setValue("Tondo iOS/\(Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") ?? "1")",
                         forHTTPHeaderField: "User-Agent")
        request.httpBody = body.data(using: .utf8)
        return request
    }
}
