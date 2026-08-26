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

    /// Set on the first 204 this process sees. Cold launch always re-registers
    /// (that is the cross-launch healing), but a healthy foreground should not
    /// spend a network round-trip re-proving what this process already proved.
    private(set) static var registered = false

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
    ///
    /// The request itself is `NativeRequest`'s (story 0010 /simplify —
    /// this used to build the secret-gated POST by hand; `PushRegistration`
    /// needed the identical scaffolding and the two had drifted into
    /// near-copies of each other).
    static func register(completion: @escaping () -> Void) {
        guard let request = NativeRequest.build(path: "device/registrations", body: "device_token=\(token)") else {
            completion()
            return
        }

        // One hop to main, then one guard: every path calls `completion`
        // plainly. A zero-cookie 204 resolves through the same DispatchGroup —
        // a group with no enters fires `notify` immediately.
        NativeRequest.session.dataTask(with: request) { _, response, _ in
            DispatchQueue.main.async {
                guard let http = response as? HTTPURLResponse,
                      http.statusCode == 204,
                      let url = response?.url,
                      let headers = http.allHeaderFields as? [String: String] else {
                    completion()
                    return
                }

                registered = true
                let cookies = HTTPCookie.cookies(withResponseHeaderFields: headers, for: url)
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
        // The delete query must be identity-only (class/service/account). The
        // first version passed the full attributes dict — including the NEW
        // value — so it never matched an existing item, SecItemAdd failed
        // with errSecDuplicateItem, both statuses were discarded, and a
        // transient read failure could fork the device identity: keeps made
        // under the phantom token orphan forever when the old one returns
        // (code review F4).
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account
        ]
        var attributes = query
        attributes[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlock
        attributes[kSecValueData as String] = Data(token.utf8)

        let status = SecItemAdd(attributes as CFDictionary, nil)
        if status == errSecDuplicateItem {
            // An item read() couldn't decode still occupies the slot —
            // overwrite in place rather than delete-and-hope.
            SecItemUpdate(query as CFDictionary,
                          [kSecValueData as String: Data(token.utf8)] as CFDictionary)
        }
    }
}
