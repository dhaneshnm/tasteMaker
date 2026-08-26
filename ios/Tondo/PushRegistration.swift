import Foundation

/// The push opt-in's client half (story 0010). Mirrors `DeviceIdentity`'s
/// networking idiom exactly — same secret header, same explicit UA, same 5s
/// timeout, same ephemeral session — because the server's `NativeEndpoint`
/// concern gates both endpoints identically.
enum PushRegistration {
    private static let session: URLSession = {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.timeoutIntervalForRequest = 5
        return URLSession(configuration: configuration)
    }()

    /// Set the moment a reader taps the invitation, cleared once the enroll
    /// POST completes. `AppDelegate`'s `didRegisterForRemoteNotificationsWithDeviceToken`
    /// reads and clears it to decide `mode` — that callback fires on EVERY
    /// cold launch (the healing path), not only after a deliberate tap, and
    /// only the tap should enroll or reload the web view (outside voice #10).
    static var enrollPending = false

    enum Mode: String {
        case enroll, refresh
    }

    /// Always calls `completion`, same philosophy as `DeviceIdentity.register`
    /// — a failed POST degrades silently. There is nothing worth retrying
    /// beyond the next cold launch or foreground (`SceneDelegate`'s own
    /// reconcile already covers both).
    ///
    /// `token` is nil only for the `.refresh, enabled: false` call — the
    /// shell learned from iOS Settings that the reader denied notifications
    /// and has no APNs token worth sending (`enabled` false is itself the
    /// whole payload the server needs to clear it).
    static func register(token: String?, mode: Mode, enabled: Bool? = nil,
                         completion: @escaping () -> Void) {
        guard let secret = Bundle.main.object(forInfoDictionaryKey: "TondoAppSecret") as? String,
              !secret.isEmpty else {
            completion()
            return
        }

        var request = URLRequest(url: Endpoint.url.appendingPathComponent("device/push_registrations"))
        request.httpMethod = "POST"
        request.setValue(secret, forHTTPHeaderField: "X-Tondo-App")
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        request.setValue("Tondo iOS/\(Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") ?? "1")",
                         forHTTPHeaderField: "User-Agent")

        // No percent-encoding needed: a Keychain UUID, a hex APNs token, the
        // mode's raw value and a bare "true"/"false" are all already
        // URL-safe characters — the same reasoning DeviceIdentity's own body
        // string relies on.
        var body = "device_token=\(DeviceIdentity.token)&mode=\(mode.rawValue)"
        if let token { body += "&apns_token=\(token)" }
        if let enabled { body += "&enabled=\(enabled)" }
        request.httpBody = body.data(using: .utf8)

        session.dataTask(with: request) { _, _, _ in
            DispatchQueue.main.async(execute: completion)
        }.resume()
    }
}
