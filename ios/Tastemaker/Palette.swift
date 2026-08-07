import SwiftUI
import UIKit

/// The token table, native side.
///
/// `DESIGN.md` rule 1: colour comes from the token table and nowhere else. These
/// read from `Assets.xcassets`, which holds the same hex values as `:root` in
/// `application.css`. Two copies of a literal is how they drift, so the asset
/// catalogue is the only place the numbers appear on this side.
extension UIColor {
    static let linen = UIColor(named: "Linen")!
    static let ink = UIColor(named: "Ink")!
    static let inkDim = UIColor(named: "InkDim")!
    static let inkFaint = UIColor(named: "InkFaint")!
    static let gold = UIColor(named: "Gold")!
    static let hairline = UIColor(named: "Hairline")!
    static let mountBg = UIColor(named: "MountBg")!
}

extension Color {
    static let linen = Color(uiColor: .linen)
    static let ink = Color(uiColor: .ink)
    static let inkDim = Color(uiColor: .inkDim)
    static let inkFaint = Color(uiColor: .inkFaint)
    static let gold = Color(uiColor: .gold)
    static let hairline = Color(uiColor: .hairline)
}

/// The two families, by PostScript name.
///
/// Static instances cut from the same latin subsets the website serves, at the
/// sizes the empty state uses. Registered through `UIAppFonts` in `Info.plist`.
enum Typeface {
    static let displayItalic = "Fraunces-Italic"
    static let body = "Newsreader-Regular"
}
