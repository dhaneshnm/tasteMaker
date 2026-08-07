# 0006 — The shell shows no native chrome

Date: 2026-08-07

Position: the Hotwire Native iOS shell hides its navigation bar and lets the web page own
the whole screen. This was the open question story 0008's spec left for the plan, and it is
direction-level because it constrains every screen built after it.

Four facts decided it, each read out of Hotwire Native 1.3.0's source rather than its
documentation. `VisitableViewController` sets `view.backgroundColor = .white` and
`HotwireWebViewController` overrides it to `.systemBackground` — neither is linen. The
visitable view is pinned to the view's edges rather than the safe area, so the strips behind
the status bar and home indicator are painted by the view controller, not the page.
`application.css` has no `prefers-color-scheme` rule, so in iOS dark mode the page would
stay linen while every native surface flipped to black. And `DefaultErrorView` is SwiftUI in
San Francisco, `.largeTitle`, iOS blue, reading "Error loading page".

A navigation bar would also put two titles on one screen: the bar takes `webView.title`
("Girl with a Pearl Earring — Tastemaker") while the masthead already says
"Tastemaker / Artwork of the Day". `decisions/0003` allows exactly one exception to the
linen skin — the full-screen artwork's mount board — and native chrome is not it.

So the shell's job is subtraction: bar hidden, interface style forced `.light`, all four
web-view layers linen, spinners gold, `window.tintColor` gold, and the error view rewritten
as a transcription of `daily/empty.html.erb`.

What this costs is the native back button, and it is paid three ways rather than one. Every
screen renders `masthead__brand → root_path`, `days/_walk` carries prev · next · today, and
swipe-back survives — but only because `LinenNavigationController` explicitly re-enables it.
UIKit disables `interactivePopGestureRecognizer` when the bar is hidden, so without that
rescue the stack silently becomes one-way. The brand link is handled by giving `^/$` a
`clear_all` presentation, so tapping "Tastemaker" unwinds to the root already at the bottom
of the stack instead of pushing a fourth screen onto it.

Prediction: through the Aug 31, 2026 kill review, no screen in this product needs a native
navigation bar, and no reader-reported confusion about "how do I go back" arrives from the
5 user conversations `BET.md` requires. Falsified if a reader in one of those conversations
raises navigation unprompted, if any screen has to be reached by a route that has no
in-page way back, or if a bridge component is added purely to restore native chrome.

Enforcement: `script/ios-build` compiles the shell in CI on `macos-latest`, so the
navigation controller cannot silently stop existing. `test/integration/path_configuration_test.rb`
fails if the bundled and served path configurations drift apart, which is what would break
the `clear_all` rule that pays for the missing back button. The swipe-back rescue is asserted
by hand in `/qa` on the simulator — named here because it is the one cost with no automated
check, and a gesture that dies silently is exactly the kind of thing a green suite hides.
