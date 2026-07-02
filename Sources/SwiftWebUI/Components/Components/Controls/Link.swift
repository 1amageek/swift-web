import SwiftWebUITheme
#if canImport(FoundationEssentials)
import FoundationEssentials
#elseif canImport(Foundation)
import Foundation
#endif
import SwiftHTML

public struct Link<Label: HTML>: WebUIAttributeComponent {
    private let destination: URL
    private let label: Label
    private let attributes: [HTMLAttribute]
    @Environment(\.styleSystem) private var styleSystem: StyleSystem
    @Environment(\.colorScheme) private var colorScheme: ColorScheme
    @Environment(\.layoutDirection) private var layoutDirection: LayoutDirection
    @Environment(\.controlSize) private var controlSize: ControlSize
    @Environment(\.isEnabled) private var isEnabled: Bool
    @Environment(\.tint) private var tint: Color?
    @Environment(\.buttonStyle) private var buttonStyle: ButtonStyleKind

    public init(
        destination: URL,
        _ attributes: HTMLAttribute...,
        @HTMLBuilder label: () -> Label
    ) {
        self.destination = destination
        self.label = label()
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
            label
        }
    }

    public func addingAttributes(_ attributes: [HTMLAttribute]) -> Self {
        Self(destination: destination, attributes: self.attributes + attributes, label: label)
    }

    private init(destination: URL, attributes: [HTMLAttribute], label: Label) {
        self.destination = destination
        self.label = label
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
                tint: tint?.cssValue
            ),
            context: StyleResolutionContext(
                styleSystem: styleSystem,
                colorScheme: colorScheme,
                layoutDirection: layoutDirection,
                controlState: isEnabled ? .enabled : .disabled
            )
        )
    }

    private var linkAttributes: [HTMLAttribute] {
        if isEnabled {
            return [.href(destination.relativeString)]
        }
        return [
            .aria("disabled", "true"),
            .tabindex(-1),
            styleAttribute(.pointerEvents("none")),
        ]
    }
}

public extension Link where Label == text {
    init(_ title: String, destination: URL, _ attributes: HTMLAttribute...) {
        self.init(destination: destination, attributes: attributes, label: text(title))
    }
}
