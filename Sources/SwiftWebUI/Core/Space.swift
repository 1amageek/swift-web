public enum Space: String, Sendable {
    case none = "0"
    case xsmall = "var(--swui-space-xs)"
    case small = "var(--swui-space-sm)"
    case medium = "var(--swui-space-md)"
    case large = "var(--swui-space-lg)"
    case xlarge = "var(--swui-space-xl)"
    case pageInline = "var(--swui-page-inline-padding)"
}

func stackSpacingValue(_ spacing: Space?) -> String {
    spacing?.rawValue ?? "var(--swui-stack-spacing)"
}

public enum HorizontalAlignment: String, Sendable {
    case leading = "flex-start"
    case center = "center"
    case trailing = "flex-end"
    case stretch = "stretch"

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
}

public struct PinnedScrollableViews: OptionSet, Sendable {
    public let rawValue: UInt32

    public init(rawValue: UInt32) {
        self.rawValue = rawValue
    }

    public static let sectionHeaders = PinnedScrollableViews(rawValue: 1 << 0)
    public static let sectionFooters = PinnedScrollableViews(rawValue: 1 << 1)
}
