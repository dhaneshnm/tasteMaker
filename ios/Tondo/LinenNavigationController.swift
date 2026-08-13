import HotwireNative
import UIKit

/// The navigation controller with no navigation bar (`decisions/0006`).
///
/// The web masthead is already the page's chrome — brand, label, and a date that
/// doubles as the door to the archive. A native bar above it would put two
/// titles on one screen and introduce a second visual system into a product that
/// ships exactly one.
///
/// Subclassing `HotwireNavigationController` rather than `UINavigationController`
/// is required, not stylistic: the superclass tracks why each
/// `VisitableViewController` appeared or disappeared, and Turbo's visit
/// lifecycle depends on it.
final class LinenNavigationController: HotwireNavigationController {
    override func viewDidLoad() {
        super.viewDidLoad()

        setNavigationBarHidden(true, animated: false)

        // The load-bearing line in this file.
        //
        // UIKit disables `interactivePopGestureRecognizer` whenever the
        // navigation bar is hidden, on the reasonable assumption that an app
        // hiding the bar has its own navigation. Ours does not — swipe-back is
        // the only native back affordance left once the bar is gone, and
        // without this the stack silently becomes one-way. Nothing crashes and
        // nothing logs; the gesture just stops existing.
        interactivePopGestureRecognizer?.delegate = self
        interactivePopGestureRecognizer?.isEnabled = true

        view.backgroundColor = .linen
    }

    /// Keep the bar hidden even if something pushes a controller that wants it.
    override func setNavigationBarHidden(_ hidden: Bool, animated: Bool) {
        super.setNavigationBarHidden(true, animated: animated)
    }

    /// Dark glyphs in the status bar, which is what is legible on linen. The
    /// window forces `.light`, so `.default` resolves to dark content.
    override var preferredStatusBarStyle: UIStatusBarStyle { .darkContent }
}

extension LinenNavigationController: UIGestureRecognizerDelegate {
    /// Only allow the swipe when there is somewhere to go back to. Letting it
    /// fire on the root controller leaves UIKit in a state where the next push
    /// does not animate.
    func gestureRecognizerShouldBegin(_ gestureRecognizer: UIGestureRecognizer) -> Bool {
        guard gestureRecognizer === interactivePopGestureRecognizer else { return true }
        return viewControllers.count > 1
    }

    /// The web page owns the whole screen, so the edge swipe overlaps whatever
    /// the page has at its left edge. Recognising simultaneously lets the page
    /// keep its own gestures instead of the shell eating them.
    func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer,
                           shouldRecognizeSimultaneouslyWith other: UIGestureRecognizer) -> Bool {
        true
    }
}
