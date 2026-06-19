import SwiftHTML

public struct Theme: Codable, Sendable, Equatable {
    public let name: String
    public let colors: ThemeColors
    public let radius: ThemeRadius
    public let spacing: ThemeSpacing
    public let typography: ThemeTypography

    public init(
        name: String,
        colors: ThemeColors,
        radius: ThemeRadius = .default,
        spacing: ThemeSpacing = .default,
        typography: ThemeTypography = .default
    ) {
        self.name = name
        self.colors = colors
        self.radius = radius
        self.spacing = spacing
        self.typography = typography
    }
}

public struct ThemeColors: Codable, Sendable, Equatable {
    public let background: String
    public let surface: String
    public let surfaceRaised: String
    public let text: String
    public let textMuted: String
    public let border: String
    public let accent: String
    public let accentText: String
    public let danger: String
    public let dangerText: String

    public init(
        background: String,
        surface: String,
        surfaceRaised: String,
        text: String,
        textMuted: String,
        border: String,
        accent: String,
        accentText: String,
        danger: String,
        dangerText: String
    ) {
        self.background = background
        self.surface = surface
        self.surfaceRaised = surfaceRaised
        self.text = text
        self.textMuted = textMuted
        self.border = border
        self.accent = accent
        self.accentText = accentText
        self.danger = danger
        self.dangerText = dangerText
    }
}

public struct ThemeRadius: Codable, Sendable, Equatable {
    public let small: String
    public let medium: String
    public let large: String
    public let pill: String

    public init(small: String, medium: String, large: String, pill: String) {
        self.small = small
        self.medium = medium
        self.large = large
        self.pill = pill
    }

    public static let `default` = ThemeRadius(
        small: "4px",
        medium: "8px",
        large: "12px",
        pill: "999px"
    )
}

public struct ThemeSpacing: Codable, Sendable, Equatable {
    public let xsmall: String
    public let small: String
    public let medium: String
    public let large: String
    public let xlarge: String

    public init(xsmall: String, small: String, medium: String, large: String, xlarge: String) {
        self.xsmall = xsmall
        self.small = small
        self.medium = medium
        self.large = large
        self.xlarge = xlarge
    }

    public static let `default` = ThemeSpacing(
        xsmall: "4px",
        small: "8px",
        medium: "12px",
        large: "16px",
        xlarge: "24px"
    )
}

public struct ThemeTypography: Codable, Sendable, Equatable {
    public let fontFamily: String
    public let monoFontFamily: String
    public let baseSize: String
    public let lineHeight: String

    public init(fontFamily: String, monoFontFamily: String, baseSize: String, lineHeight: String) {
        self.fontFamily = fontFamily
        self.monoFontFamily = monoFontFamily
        self.baseSize = baseSize
        self.lineHeight = lineHeight
    }

    public static let `default` = ThemeTypography(
        fontFamily: "-apple-system, BlinkMacSystemFont, \"SF Pro Text\", \"SF Pro Display\", system-ui, sans-serif",
        monoFontFamily: "\"JetBrains Mono\", ui-monospace, \"SFMono-Regular\", \"SF Mono\", Menlo, Consolas, \"Liberation Mono\", monospace",
        baseSize: "16px",
        lineHeight: "1.5"
    )
}

extension Theme {
    public static let light = Theme(
        name: "light",
        colors: ThemeColors(
            background: "#f7f8fa",
            surface: "#ffffff",
            surfaceRaised: "#ffffff",
            text: "#16181d",
            textMuted: "#626975",
            border: "#d9dee7",
            accent: "#1769e0",
            accentText: "#ffffff",
            danger: "#c93636",
            dangerText: "#ffffff"
        )
    )

    public static let system = Theme(
        name: "system",
        colors: ThemeColors(
            background: "#f7f8fa",
            surface: "#ffffff",
            surfaceRaised: "#ffffff",
            text: "#16181d",
            textMuted: "#626975",
            border: "#d9dee7",
            accent: "#1769e0",
            accentText: "#ffffff",
            danger: "#c93636",
            dangerText: "#ffffff"
        )
    )

    public static let dark = Theme(
        name: "dark",
        colors: ThemeColors(
            background: "#111318",
            surface: "#181b22",
            surfaceRaised: "#20242d",
            text: "#f4f6f8",
            textMuted: "#a8b0bd",
            border: "#343a46",
            accent: "#65a8ff",
            accentText: "#07111f",
            danger: "#ff7777",
            dangerText: "#1f0707"
        )
    )
}

public extension Theme {
    var cssVariableStyle: Style {
        Style {
            .custom("--swui-background", colors.background)
            .custom("--swui-surface", colors.surface)
            .custom("--swui-surface-raised", colors.surfaceRaised)
            .custom("--swui-text", colors.text)
            .custom("--swui-text-muted", colors.textMuted)
            .custom("--swui-border", colors.border)
            .custom("--swui-accent", colors.accent)
            .custom("--swui-accent-text", colors.accentText)
            .custom("--swui-danger", colors.danger)
            .custom("--swui-danger-text", colors.dangerText)
            .custom("--swui-radius-small", radius.small)
            .custom("--swui-radius-medium", radius.medium)
            .custom("--swui-radius-large", radius.large)
            .custom("--swui-radius-pill", radius.pill)
            .custom("--swui-space-xs", spacing.xsmall)
            .custom("--swui-space-sm", spacing.small)
            .custom("--swui-space-md", spacing.medium)
            .custom("--swui-space-lg", spacing.large)
            .custom("--swui-space-xl", spacing.xlarge)
            .custom("--swui-font-family", typography.fontFamily)
            .custom("--swui-mono-font-family", typography.monoFontFamily)
            .custom("--swui-base-size", typography.baseSize)
            .custom("--swui-line-height", typography.lineHeight)
        }
    }
}
