import SwiftWebStyle

package extension StyleClass {
    static let swuiVStack: StyleClass = "swui-vstack"
    static let swuiHStack: StyleClass = "swui-hstack"
    static let swuiLazyVStack: StyleClass = "swui-lazy-vstack"
    static let swuiLazyHStack: StyleClass = "swui-lazy-hstack"
    static let swuiLazyVGrid: StyleClass = "swui-lazy-vgrid"
    static let swuiLazyHGrid: StyleClass = "swui-lazy-hgrid"

    /// Axis greed markers for spacer-derived greed, resolved at render time by
    /// StackSpacerDetection and emitted on every stack a `Spacer` reaches
    /// (frame-terminated). Kept distinct from the `.frame` fill markers
    /// (`swui-fill-*`) so the stylesheet consumes them with direct
    /// `parent > child` rules only — never a `:has()` that could pierce a
    /// bounding frame.
    static let swuiGreedyHorizontal: StyleClass = "swui-greedy-h"
    static let swuiGreedyVertical: StyleClass = "swui-greedy-v"

    static let swuiGapStack: StyleClass = "swui-gap-stack"
    static let swuiGapNone: StyleClass = "swui-gap-none"
    static let swuiGapExtraSmall: StyleClass = "swui-gap-xs"
    static let swuiGapSmall: StyleClass = "swui-gap-sm"
    static let swuiGapMedium: StyleClass = "swui-gap-md"
    static let swuiGapLarge: StyleClass = "swui-gap-lg"
    static let swuiGapExtraLarge: StyleClass = "swui-gap-xl"

    static let swuiAlignItemsLeading: StyleClass = "swui-ai-leading"
    static let swuiAlignItemsTop: StyleClass = "swui-ai-top"
    static let swuiAlignItemsCenter: StyleClass = "swui-ai-center"
    static let swuiAlignItemsTrailing: StyleClass = "swui-ai-trailing"
    static let swuiAlignItemsBottom: StyleClass = "swui-ai-bottom"
    static let swuiAlignItemsStretch: StyleClass = "swui-ai-stretch"

    static let swuiJustifyItemsLeading: StyleClass = "swui-ji-leading"
    static let swuiJustifyItemsCenter: StyleClass = "swui-ji-center"
    static let swuiJustifyItemsTrailing: StyleClass = "swui-ji-trailing"
    static let swuiJustifyItemsStretch: StyleClass = "swui-ji-stretch"
}
