import HotwireNative
import UIKit
import WebKit

/// Every reader-facing screen. The page owns the whole thing; this class exists
/// to stop iOS painting anything the page did not ask for.
///
/// Subclassing `HotwireWebViewController` rather than `VisitableViewController`
/// keeps the bridge lifecycle callbacks intact — which story 0031's
/// `ShareComponent` now uses (`delegate.destination` resolves to an
/// instance of this class, cast back to `UIViewController` to present from).
final class LinenWebViewController: HotwireWebViewController {
    override func viewDidLoad() {
        super.viewDidLoad()

        // `HotwireWebViewController.viewDidLoad` has just set this to
        // `.systemBackground`, and `VisitableViewController` before it set
        // `.white`. Neither is linen, and this is the layer that paints the
        // safe-area strips, because `visitableView` is pinned to the view's
        // edges rather than to the safe area.
        view.backgroundColor = .linen

        // Must be set before anything touches `screenshotContainerView`: that
        // view is lazy and captures `self.backgroundColor` at initialisation,
        // so setting this later leaves the app-switcher snapshot letterboxed
        // in the wrong colour with no way to correct it.
        visitableView.backgroundColor = .linen

        visitableView.activityIndicatorView.color = .gold
        visitableView.refreshControl.tintColor = .gold

        NotificationCenter.default.addObserver(
            self,
            selector: #selector(contentSizeCategoryDidChange),
            name: UIContentSizeCategory.didChangeNotification,
            object: nil
        )
    }

    /// The remaining three layers. The web view is only available once Turbo
    /// hands it over, and it moves between visitables, so this runs on every
    /// activation rather than once at load.
    override func visitableDidActivateWebView(_ webView: WKWebView) {
        super.visitableDidActivateWebView(webView)

        webView.backgroundColor = .linen
        webView.scrollView.backgroundColor = .linen

        // Without this the web view draws its own opaque white beneath the
        // page, which wins over every colour set above.
        webView.isOpaque = false
    }

    /// The user script fixes the size at load; this covers the reader who
    /// changes the setting while the app is open — which, for a setting people
    /// adjust while looking at the thing they are trying to read, is the common
    /// case rather than the edge case.
    @objc private func contentSizeCategoryDidChange() {
        visitableView.webView?.evaluateJavaScript(
            DynamicType.javaScript(rootFontSize: DynamicType.currentRootFontSize)
        )
    }
}
