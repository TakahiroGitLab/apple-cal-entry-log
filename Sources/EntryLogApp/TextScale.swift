import SwiftUI

/// How large to draw the listing.
///
/// A listing is read at arm's length on a desk and up close on a
/// laptop, and the useful size is not the same. Rather than scale the
/// rendered view -- which blurs text and leaves the layout thinking it
/// is the old size -- every font in a row is derived from a base size
/// multiplied by this, so the rows lay out at whatever size they are
/// actually drawn.
struct TextScale: Equatable {

    /// What the window opens at, and what ⌘0 returns to.
    static let standard = TextScale(factor: 1)

    static let steps: [Double] = [0.85, 1, 1.15, 1.3, 1.5, 1.75]

    var factor: Double

    func font(_ base: Double, weight: Font.Weight = .regular) -> Font {
        .system(size: base * factor, weight: weight)
    }

    /// The next step up or down, or this one when there is no further
    /// to go.
    func stepped(by direction: Int) -> TextScale {

        let current = Self.steps.firstIndex(of: factor)
            ?? Self.steps.firstIndex(of: 1)
            ?? 0

        let wanted = min(max(current + direction, 0), Self.steps.count - 1)

        return TextScale(factor: Self.steps[wanted])
    }

    var canGrow: Bool { factor < Self.steps.last! }
    var canShrink: Bool { factor > Self.steps.first! }

    private static let key = "textScale"

    /// What was chosen last time, or the standard size.
    static func remembered() -> TextScale {
        guard let factor = UserDefaults.standard.object(forKey: key) as? Double,
              steps.contains(factor)
        else { return .standard }

        return TextScale(factor: factor)
    }

    func remember() {
        UserDefaults.standard.set(factor, forKey: Self.key)
    }
}
