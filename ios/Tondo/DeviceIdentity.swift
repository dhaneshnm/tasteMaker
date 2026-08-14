import Foundation
import WebKit

/// The device key (story 0015, decisions/0011).
///
/// A UUID minted once and kept in the Keychain — it survives app reinstall,
/// dies with a device wipe, and deliberately does NOT sync to iCloud: an
/// iCloud-synced identifier would quietly turn the device key into an account
/// key shared across the reader's devices, which is the merge decision 0011
/// explicitly declined.
///
///     first launch                     every launch after
///     ────────────                     ──────────────────
///     mint UUID → Keychain             read UUID from Keychain
///          │                                │
///          └──── POST /device/registrations with X-Tondo-App ────┐
///                                                                ▼
///                              204 + Set-Cookie: device=signed(uuid)
///                                                                │
///                    copy into WKWebsiteDataStore ◄──────────────┘
///                    (WKWebView then carries it on every request)
///
/// Registration is idempotent — same UUID, same identity, cookie re-issued —
/// so calling it on every cold launch is the retry mechanism, not a special
/// case. If it fails (first-ever launch in airplane mode), the shell proceeds
/// anyway: the reader sees the landing page's art, the sign-in fragment stays
/// empty for the shell's user agent, and the next foreground retries.
enum DeviceIdentity {
    private static let service = Bundle.main.bundleIdentifier ?? "app.tondo"
    private static let account = "device-token"

    /// Read-or-mint. `AfterFirstUnlock` so a background relaunch on a locked
    /// phone can still read it; device-only (no `kSecAttrSynchronizable`).
    static var token: String {
        if let existing = read() { return existing }
        let minted = UUID().uuidString
        store(minted)
        return minted
    }

    /// Registers with the server and bridges the resulting cookie into the
    /// web view's store. Always calls `completion` — on failure the shell
    /// routes anyway, degraded to the public landing page (plan, constraint 3).
    static func register(completion: @escaping () -> Void) {
        guard let secret = Bundle.main.object(forInfoDictionaryKey: "TondoAppSecret") as? String,
              !secret.isEmpty else {
            completion()
            return
        }

        var request = URLRequest(url: Endpoint.url.appendingPathComponent("device/registrations"))
        request.httpMethod = "POST"
        request.setValue(secret, forHTTPHeaderField: "X-Tondo-App")
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        // The server judges user agents (`allow_browser`), and the sign-in
        // fragment renders empty for this one — an explicit identity, not
        // whatever CFNetwork writes this year (eng review A4).
        request.setValue("Tondo iOS/\(Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") ?? "1")",
                         forHTTPHeaderField: "User-Agent")
        request.httpBody = "device_token=\(token)".data(using: .utf8)

        // An ephemeral session: the ONLY cookie jar that matters is the web
        // view's. Letting URLSession's shared jar hold a second copy invites
        // the two to disagree.
        let configuration = URLSessionConfiguration.ephemeral
        let session = URLSession(configuration: configuration)

        session.dataTask(with: request) { _, response, _ in
            guard let http = response as? HTTPURLResponse,
                  http.statusCode == 204,
                  let url = response?.url,
                  let headers = http.allHeaderFields as? [String: String] else {
                DispatchQueue.main.async(execute: completion)
                return
            }

            let cookies = HTTPCookie.cookies(withResponseHeaderFields: headers, for: url)
            guard !cookies.isEmpty else {
                DispatchQueue.main.async(execute: completion)
                return
            }

            DispatchQueue.main.async {
                let store = WKWebsiteDataStore.default().httpCookieStore
                let group = DispatchGroup()
                for cookie in cookies {
                    group.enter()
                    store.setCookie(cookie) { group.leave() }
                }
                group.notify(queue: .main, execute: completion)
            }
        }.resume()
    }

    // MARK: - Keychain

    private static func read() -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]
        var item: CFTypeRef?
        guard SecItemCopyMatching(query as CFDictionary, &item) == errSecSuccess,
              let data = item as? Data,
              let token = String(data: data, encoding: .utf8),
              !token.isEmpty else { return nil }
        return token
    }

    private static func store(_ token: String) {
        let attributes: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecAttrAccessible as String: kSecAttrAccessibleAfterFirstUnlock,
            kSecValueData as String: Data(token.utf8)
        ]
        SecItemDelete(attributes as CFDictionary)
        SecItemAdd(attributes as CFDictionary, nil)
    }
}
