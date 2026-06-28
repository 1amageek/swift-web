import SwiftHTML
import SwiftWebUITheme
import SwiftWebStyle

extension Space {
    func paddingClassList(edges: Edge.Set) -> StyleClassList {
        if edges == .all {
            return styleClasses(paddingClassName(.all))
        }
        if edges == .horizontal {
            return styleClasses(paddingClassName(.horizontal))
        }
        if edges == .vertical {
            return styleClasses(paddingClassName(.vertical))
        }

        var classes: [StyleClass?] = []
        if edges.contains(.top) {
            classes.append(paddingClassName(.top))
        }
        if edges.contains(.leading) {
            classes.append(paddingClassName(.leading))
        }
        if edges.contains(.bottom) {
            classes.append(paddingClassName(.bottom))
        }
        if edges.contains(.trailing) {
            classes.append(paddingClassName(.trailing))
        }
        return styleClasses(classes)
    }
}

struct StackGap: Sendable, Equatable {
    let className: StyleClass?
    let cssValue: String?
}

func stackGap(_ spacing: Space?) -> StackGap {
    StackGap(className: spacing?.gapClassName ?? .swuiGapStack, cssValue: nil)
}

/// SwiftUI-canonical numeric spacing (points → px). A `nil` spacing falls back
/// to the theme default stack gap, matching SwiftUI's "system spacing".
func stackGap(_ spacing: Double?) -> StackGap {
    if let spacing {
        StackGap(className: nil, cssValue: pixelValue(spacing))
    } else {
        StackGap(className: .swuiGapStack, cssValue: nil)
    }
}

public enum HorizontalAlignment: String, Sendable {
    case leading = "flex-start"
    case center = "center"
    case trailing = "flex-end"
    case stretch = "stretch"

    var alignItemsClassName: StyleClass {
        switch self {
        case .leading:
            .swuiAlignItemsLeading
        case .center:
            .swuiAlignItemsCenter
        case .trailing:
            .swuiAlignItemsTrailing
        case .stretch:
            .swuiAlignItemsStretch
        }
    }

    var justifyItemsClassName: StyleClass {
        switch self {
        case .leading:
            .swuiJustifyItemsLeading
        case .center:
            .swuiJustifyItemsCenter
        case .trailing:
            .swuiJustifyItemsTrailing
        case .stretch:
            .swuiJustifyItemsStretch
        }
    }

    var textAlign: String {
        switch self {
        case .leading:
            "left"
        case .center, .stretch:
            "center"
        case .trailing:
            "right"
        }
    }
}

public enum VerticalAlignment: String, Sendable {
    case top = "flex-start"
    case center = "center"
    case bottom = "flex-end"
    case stretch = "stretch"

    var alignItemsClassName: StyleClass {
        switch self {
        case .top:
            .swuiAlignItemsTop
        case .center:
            .swuiAlignItemsCenter
        case .bottom:
            .swuiAlignItemsBottom
        case .stretch:
            .swuiAlignItemsStretch
        }
    }
}

public struct PinnedScrollableViews: OptionSet, Sendable {
    public let rawValue: UInt32

    public init(rawValue: UInt32) {
        self.rawValue = rawValue
    }

    public static let sectionHeaders = PinnedScrollableViews(rawValue: 1 << 0)
    public static let sectionFooters = PinnedScrollableViews(rawValue: 1 << 1)
}
