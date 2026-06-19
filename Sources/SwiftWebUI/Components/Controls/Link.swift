import SwiftHTML

public struct Link: WebUIAttributeComponent {
    private let text: String
    private let href: String
    private let attributes: [HTMLAttribute]
    @Environment(\.theme) private var theme
    @Environment(\.styleSystem) private var styleSystem
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.layoutDirection) private var layoutDirection
    @Environment(\.controlSize) private var controlSize
    @Environment(\.isEnabled) private var isEnabled
    @Environment(\.tint) private var tint
    @Environment(\.buttonStyle) private var buttonStyle

    public init(
        _ text: String,
        href: String,
        _ attributes: HTMLAttribute...
    ) {
        self.text = text
        self.href = href
        self.attributes = attributes
    }

    @HTMLBuilder
    public var body: some HTML {
        Element(
            "a",
            attributes: mergedAttributes(
                class: className,
                styles: styleValue,
                extra: linkAttributes + attributes
            )
        ) {
            text
        }
    }

    public func addingAttributes(_ attributes: [HTMLAttribute]) -> Self {
        Self(text, href: href, attributes: self.attributes + attributes)
    }

    private init(_ text: String, href: String, attributes: [HTMLAttribute]) {
        self.text = text
        self.href = href
        self.attributes = attributes
    }

    private var className: String {
        if buttonStyle == .automatic {
            return "swui-link"
        }
        return buttonStyleResult.classNames.joined(separator: " ")
    }

    private var styleValue: Style {
        if buttonStyle == .automatic {
            return Style()
        }
        return buttonStyleResult.style
    }

    private var buttonStyleResult: ButtonStyleResult {
        buttonStyle.resolve(
            configuration: ButtonStyleConfiguration(
                prominence: .secondary,
                controlSize: controlSize,
                isEnabled: isEnabled,
                tint: tint
            ),
            context: StyleResolutionContext(
                theme: theme,
                styleSystem: styleSystem,
                colorScheme: colorScheme,
                layoutDirection: layoutDirection,
                controlState: isEnabled ? .enabled : .disabled
            )
        )
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
