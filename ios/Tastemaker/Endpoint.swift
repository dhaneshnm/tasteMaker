import Foundation

/// Where the shell points.
///
/// The value comes from `TASTEMAKER_URL` in `Config/*.xcconfig` by way of
/// `Info.plist`, never from a literal in Swift. A hardcoded start URL is a start
/// URL that ships to the App Store pointing at somebody's laptop.
enum Endpoint {
    static let url: URL = {
        guard let raw = Bundle.main.object(forInfoDictionaryKey: "TastemakerURL") as? String,
              !raw.isEmpty,
              let url = URL(string: raw),
              url.scheme != nil,
              url.host != nil
        else {
            // Loudly, and at launch. A shell that silently falls back to some
            // default host is worse than one that will not start: the failure
            // would surface as a blank screen in App Review with no explanation.
            fatalError("""
            TASTEMAKER_URL is missing or unparseable.
            Check Config/Debug.xcconfig and Config/Release.xcconfig — note that `//` \
            must be escaped as `/$()/` or xcconfig reads the rest of the line as a comment.
            """)
        }

        return url
    }()

    /// The path configuration served by Rails, so navigation rules can change
    /// without an App Store review. `public/configurations/ios_v1.json`.
    static var pathConfigurationURL: URL {
        url.appendingPathComponent("configurations/ios_v1.json")
    }
}
