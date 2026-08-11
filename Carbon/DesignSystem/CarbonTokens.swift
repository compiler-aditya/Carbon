import SwiftUI

/// The palette. Three hues — violet, red, olive — plus neutrals. Do not add a fourth.
///
/// Colours live in the asset catalog so light and dark are resolved by the system rather than
/// by a `colorScheme` check in every view.
enum CarbonColor {
    static let paper = Color("paper")
    static let paperRaised = Color("paperRaised")
    static let ink = Color("ink")
    static let inkMuted = Color("inkMuted")
    static let carbon = Color("carbon")
    static let carbonSoft = Color("carbonSoft")
    static let rule = Color("rule")
    static let stamp = Color("stamp")
    static let stampSoft = Color("stampSoft")
    static let confirm = Color("confirm")
}

/// Three system faces, and the *pairing* is what makes it distinctive: iOS utilities almost
/// never set titles in a serif or data in mono.
///
/// Every style is built from a text style rather than a fixed point size, so Dynamic Type
/// works everywhere without a single manual scaling calculation.
///
/// The mono choice is functional as well as visual: monospaced digits disambiguate 1/7, 0/O
/// and 5/S — exactly the characters recognition confuses.
enum CarbonFont {
    static let title = Font.system(.largeTitle, design: .serif).weight(.semibold)
    static let screenTitle = Font.system(.title, design: .serif).weight(.semibold)
    static let cardTitle = Font.system(.headline, design: .serif)
    static let sectionHeader = Font.system(.caption, design: .default).weight(.semibold)
    static let fieldLabel = Font.system(.caption, design: .default).weight(.medium)

    /// The workhorse. Every extracted value, every number, every cell.
    static let dataValue = Font.system(.body, design: .monospaced)
    static let dataValueLarge = Font.system(.title2, design: .monospaced).weight(.medium)

    static let body = Font.system(.body)
    static let callout = Font.system(.callout)
    static let caption = Font.system(.caption)
    static let stamp = Font.system(.caption2, design: .default).weight(.semibold)
}

/// 4pt grid.
enum CarbonSpacing {
    static let hair: CGFloat = 4
    static let tight: CGFloat = 8
    static let snug: CGFloat = 12
    static let regular: CGFloat = 16
    static let loose: CGFloat = 24
    static let section: CGFloat = 32
    static let screen: CGFloat = 48
}

/// Table cells have square corners. Grids are grids.
enum CarbonRadius {
    static let card: CGFloat = 10
    static let chip: CGFloat = 6
    static let cell: CGFloat = 0
}

extension View {
    /// Caps content at a readable measure and centres what is left.
    ///
    /// A full-width button on an 834pt iPad is not a button, it is a banner, and a line of
    /// body text run edge to edge across a tablet is genuinely harder to read. Everything the
    /// eye has to track — prose, forms, actions — gets a column. Grids and tables do not:
    /// those want the whole page.
    func carbonReadableWidth(_ maxWidth: CGFloat = 560) -> some View {
        frame(maxWidth: maxWidth).frame(maxWidth: .infinity)
    }

    /// The app background. Used instead of a plain `.background` so the paper colour is
    /// applied the same way everywhere.
    func carbonBackground() -> some View {
        background(CarbonColor.paper.ignoresSafeArea())
    }

    /// Bounds Dynamic Type at accessibility3, which every screen is expected to survive.
    func carbonTypeSize() -> some View {
        dynamicTypeSize(...DynamicTypeSize.accessibility3)
    }
}
