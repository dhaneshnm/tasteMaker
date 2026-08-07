import UIKit
import WebKit

/// iOS "Larger Text", wired into a stylesheet that does not listen for it.
///
/// `application.css` sizes everything in `rem` against the browser's default
/// root of 16px. WKWebView does not scale that root with the system content
/// size category, so before this file the Settings slider had no effect
/// anywhere in the shell — the app was simply deaf to it.
///
/// The fix is to set the root font size from `preferredContentSizeCategory` and
/// let every existing `rem` follow. Nothing in the stylesheet changes.
enum DynamicType {
    /// The web's own default. `rem` is relative to this.
    static let baseFontSize: Double = 16

    /// **The cap is a design decision, not a rounding convenience.**
    ///
    /// "Art and text visible together" is a Better-bucket quality bar and the
    /// one the category leader fails. Larger type pushes the note down against
    /// the 55vh cap on `.plate__img`, so past a point the reader gets a bigger
    /// blurb and no painting — which is the failure this product exists to
    /// avoid. Accessibility sizes are honoured up to here and then stop
    /// growing, because a capped scale still reads and a swallowed artwork
    /// does not.
    ///
    /// **1.25 is measured, not chosen.** `test/system/dynamic_type_test.rb`
    /// puts the note's first line at these distances from a 667px fold:
    ///
    ///     1.20 → 31px of slack
    ///     1.25 → 19px
    ///     1.30 →  8px
    ///     1.35 → -4px, over the fold
    ///
    /// The plan's original 1.35 breaks the bar outright. 1.30 fits, but only by
    /// 8px against a single fixture note — and note and title lengths vary with
    /// every artwork the curator picks, so 8px is a coincidence rather than a
    /// cap. 1.25 keeps a real accessibility gain with room for a longer title.
    static let maximumScale: Double = 1.25

    /// Matches the ratios UIKit uses between content size categories, so text
    /// in the shell grows at the same rate as text in every other app.
    static func scale(for category: UIContentSizeCategory) -> Double {
        let scale: Double = switch category {
        case .extraSmall: 0.82
        case .small: 0.88
        case .medium: 0.94
        case .large: 1.00                       // the system default
        case .extraLarge: 1.06
        case .extraExtraLarge: 1.12
        case .extraExtraExtraLarge: 1.20        // largest non-accessibility size
        case .accessibilityMedium: 1.25
        case .accessibilityLarge: 1.25
        case .accessibilityExtraLarge: 1.25
        case .accessibilityExtraExtraLarge: 1.25
        case .accessibilityExtraExtraExtraLarge: 1.25
        default: 1.00
        }

        return min(scale, maximumScale)
    }

    static func rootFontSize(for category: UIContentSizeCategory) -> Double {
        (baseFontSize * scale(for: category) * 100).rounded() / 100
    }

    static var currentRootFontSize: Double {
        rootFontSize(for: UIApplication.shared.preferredContentSizeCategory)
    }

    /// Set as an inline style on `<html>` so it beats the stylesheet without
    /// needing `!important` and without the stylesheet knowing this exists.
    static func javaScript(rootFontSize: Double) -> String {
        "document.documentElement.style.fontSize = '\(rootFontSize)px';"
    }

    /// Injected at document start so the first paint is already at the right
    /// size. Running at document end would show one frame at 16px and then
    /// reflow, which is a visible jolt on every single visit.
    static func userScript() -> WKUserScript {
        WKUserScript(
            source: javaScript(rootFontSize: currentRootFontSize),
            injectionTime: .atDocumentStart,
            forMainFrameOnly: true
        )
    }
}
