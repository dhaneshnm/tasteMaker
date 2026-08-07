import HotwireNative
import SwiftUI

/// The one screen the web cannot draw.
///
/// Direction E2 from the design board: the empty state, transcribed. It is a
/// structural twin of `app/views/daily/empty.html.erb` — ornament, one display
/// italic line, one note, one gold caps link — because a reader who loses signal
/// should land somewhere that is recognisably the same product, not in
/// `DefaultErrorView`'s San Francisco and iOS blue on white.
///
/// Every measurement here is the `rem` value from `application.css` resolved
/// against a 16px root: `.coda__line` 1.15rem, `.coda__note` 0.95rem,
/// `.caps-link` 0.78rem with 0.2em tracking.
struct LinenErrorView: ErrorPresentableView {
    let error: HotwireNativeError
    let handler: ErrorPresenter.Handler?

    var body: some View {
        VStack(spacing: 0) {
            ornament

            Text("The gallery is out of reach.")
                .font(.custom(Typeface.displayItalic, size: 18.4))
                .foregroundStyle(Color.inkDim)
                .padding(.bottom, 22.4)

            Text("There is no connection right now. The artwork is still there — this is only the door.")
                .font(.custom(Typeface.body, size: 15.2))
                .foregroundStyle(Color.inkFaint)
                .lineSpacing(15.2 * 0.7)
                .multilineTextAlignment(.center)
                .frame(maxWidth: 400)
                .padding(.bottom, 32)

            if let handler {
                Button(action: handler) {
                    // Sentence case in the source, uppercased by the view.
                    //
                    // Not a style preference: VoiceOver spells an uppercase
                    // string literal out letter by letter — "T, R, Y, A, G, A,
                    // I, N". `.textCase` changes the rendering and leaves the
                    // accessibility string alone. The web is already safe here
                    // because `.caps-link` uppercases in CSS, so the DOM text
                    // stays sentence case.
                    Text("Try again")
                        .textCase(.uppercase)
                        .font(.custom(Typeface.body, size: 12.5))
                        .tracking(2.5)
                        .foregroundStyle(Color.gold)
                        // DESIGN.md: nothing tappable is smaller than 44pt.
                        .frame(minWidth: 44, minHeight: 44)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }
        }
        .padding(32)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.linen)
    }

    /// `.ornament` — `———  ✦  ———`, built out of `::before` and `::after` on the
    /// web. The star is deliberately left in the system font: U+2726 is outside
    /// the latin subset, so it falls back on the website too, and matching that
    /// fallback is what keeps the two surfaces identical.
    private var ornament: some View {
        HStack(spacing: 14.4) {
            Text("———")
                .font(.system(size: 11.2))
                .foregroundStyle(Color.hairline)
            Text("✦")
                .font(.system(size: 14.4))
                .foregroundStyle(Color.gold)
                .tracking(7.2)
            Text("———")
                .font(.system(size: 11.2))
                .foregroundStyle(Color.hairline)
        }
        .accessibilityHidden(true)
        .padding(.bottom, 25.6)
    }
}
