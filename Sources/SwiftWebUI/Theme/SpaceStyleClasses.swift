import SwiftWebStyle

package extension Space {
    var gapClassName: StyleClass {
        switch self {
        case .none:
            .swuiGapNone
        case .xsmall:
            .swuiGapExtraSmall
        case .small:
            .swuiGapSmall
        case .medium:
            .swuiGapMedium
        case .large:
            .swuiGapLarge
        case .xlarge:
            .swuiGapExtraLarge
        }
    }

    var utilitySuffix: String {
        switch self {
        case .none:
            "none"
        case .xsmall:
            "xs"
        case .small:
            "sm"
        case .medium:
            "md"
        case .large:
            "lg"
        case .xlarge:
            "xl"
        }
    }

    func paddingClassName(_ axis: PaddingClassAxis) -> StyleClass {
        StyleClass("swui-\(axis.rawValue)-\(utilitySuffix)")
    }
}
