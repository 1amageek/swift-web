import SwiftHTML

public struct ButtonLink: WebUIAttributeComponent {
    private let text: String
    private let href: String
    private let prominence: ButtonProminence
    private let attributes: [HTMLAttribute]
    @Environment(\.theme) private var theme
    @Environment(\.styleSystem) private var styleSystem
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.layoutDirection) private var layoutDirection
    @Environment(\.controlSize) private var controlSize
    @Environment(\.isEnabled) private var isEnabled
    @Environment(\.tint) private var tint
    @Environment(\.buttonStyle) private var buttonStyle

    public init(_ text: String, href: String, prominence: ButtonProminence = .secondary, _ attributes: HTMLAttribute...) {
        self.text = text
        self.href = href
        self.prominence = prominence
        self.attributes = attributes
    }

    public init(_ text: String, href: String, primary: Bool) {
        self.init(text, href: href, prominence: primary ? .primary : .secondary)
    }

    @HTMLBuilder
    public var body: some HTML {
        Element(
            "a",
            attributes: mergedAttributes(
                class: buttonClassName,
                styles: buttonStyleValue,
                extra: linkAttributes + attributes
            )
        ) {
            text
        }
    }

    public func addingAttributes(_ attributes: [HTMLAttribute]) -> Self {
        Self(text, href: href, prominence: prominence, attributes: self.attributes + attributes)
    }

    private init(_ text: String, href: String, prominence: ButtonProminence, attributes: [HTMLAttribute]) {
        self.text = text
        self.href = href
        self.prominence = prominence
        self.attributes = attributes
    }

    private var styleConfiguration: ButtonStyleConfiguration {
        ButtonStyleConfiguration(
            prominence: prominence,
            controlSize: controlSize,
            isEnabled: isEnabled,
            tint: tint
        )
    }

    private var styleContext: StyleResolutionContext {
        StyleResolutionContext(
            theme: theme,
            styleSystem: styleSystem,
            colorScheme: colorScheme,
            layoutDirection: layoutDirection,
            controlState: isEnabled ? .enabled : .disabled
        )
    }

    private var styleResult: ButtonStyleResult {
        buttonStyle.resolve(configuration: styleConfiguration, context: styleContext)
    }

    private var buttonClassName: String {
        styleResult.classNames.joined(separator: " ")
    }

    private var buttonStyleValue: Style {
        styleResult.style
    }

    private var linkAttributes: [HTMLAttribute] {
        if isEnabled {
            return [.href(href)]
        }
        return [
            .aria("disabled", "true"),
            .tabindex(-1),
            styleAttribute(.pointerEvents("none")),
        ]
    }
}

public enum ButtonProminence: Sendable, Equatable {
    case primary
    case secondary

    var className: String {
        switch self {
        case .primary:
            "swui-button swui-button-primary"
        case .secondary:
            // The secondary surface fill is owned by the shared material, so the
            // class always carries the material tokens alongside the variant —
            // the `.swui-button-secondary` rule no longer paints a background.
            "swui-button swui-button-secondary \(MaterialClass.material) \(MaterialClass.thin)"
        }
    }
}
