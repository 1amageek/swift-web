import SwiftHTML
import SwiftWebStyle

public struct StyleSystemUtility: Sendable, Equatable {
    public let className: StyleClass
    public let style: Style

    public init(className: StyleClass, style: Style) {
        self.className = className
        self.style = style
    }
}

public extension StyleSystemUtility {
    static let defaults: [StyleSystemUtility] = [
        .background("background", token: "--swui-background"),
        .background("surface", token: "--swui-surface"),
        .background("surface-raised", token: "--swui-surface-raised"),
        .background("accent", token: "--swui-accent"),
        .background("danger", token: "--swui-danger"),
        .foreground("primary", token: "--swui-text"),
        .foreground("secondary", token: "--swui-text-muted"),
        .foreground("muted", token: "--swui-text-muted"),
        .foreground("accent", token: "--swui-accent"),
        .foreground("accent-text", token: "--swui-accent-text"),
        .foreground("danger", token: "--swui-danger"),
        .foreground("danger-text", token: "--swui-danger-text"),
        .border("default", token: "--swui-border"),
        .border("accent", token: "--swui-accent"),
        .border("danger", token: "--swui-danger"),
        .radius("sm", token: "--swui-radius-small"),
        .radius("md", token: "--swui-radius-medium"),
        .radius("lg", token: "--swui-radius-large"),
        .radius("pill", token: "--swui-radius-pill"),
        .radius("container", token: "--swui-container-radius"),
        .shadow("container", token: "--swui-container-shadow"),
    ]

    static func background(_ name: String, token: String) -> StyleSystemUtility {
        StyleSystemUtility(
            className: StyleClass("swui-bg-\(name)"),
            style: .background("var(\(token))")
        )
    }

    static func foreground(_ name: String, token: String) -> StyleSystemUtility {
        StyleSystemUtility(
            className: StyleClass("swui-fg-\(name)"),
            style: .color("var(\(token))")
        )
    }

    static func border(_ name: String, token: String) -> StyleSystemUtility {
        StyleSystemUtility(
            className: StyleClass("swui-border-\(name)"),
            style: .borderColor("var(\(token))")
        )
    }

    static func radius(_ name: String, token: String) -> StyleSystemUtility {
        StyleSystemUtility(
            className: StyleClass("swui-radius-\(name)"),
            style: .borderRadius("var(\(token))")
        )
    }

    static func shadow(_ name: String, token: String) -> StyleSystemUtility {
        StyleSystemUtility(
            className: StyleClass("swui-shadow-\(name)"),
            style: .boxShadow("var(\(token))")
        )
    }
}

public extension StyleUtilityRegistry {
    static var swiftWebUI: StyleUtilityRegistry {
        StyleUtilityRegistry(
            definitions: StyleSystemUtility.defaults.map { utility in
                .token(utility.className.rawValue, style: utility.style)
            }
        )
    }
}
