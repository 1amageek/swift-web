import SwiftWebUITheme
#if canImport(FoundationEssentials)
import FoundationEssentials
#elseif canImport(Foundation)
import Foundation
#endif
import SwiftHTML

public struct NavigationLink<Label: HTML>: AttributeComponent {
    private let destination: URL
    private let attributes: [HTMLAttribute]
    private let label: Label
    @Environment({ $0.theme }) private var theme: Theme
    @Environment({ $0.colorScheme }) private var colorScheme: ColorScheme
    @Environment({ $0.layoutDirection }) private var layoutDirection: LayoutDirection
    @Environment({ $0.controlSize }) private var controlSize: ControlSize
    @Environment({ $0.isEnabled }) private var isEnabled: Bool
    @Environment({ $0.tint }) private var tint: Color?
    @Environment({ $0.buttonStyle }) private var buttonStyle: ButtonStyleKind

    public init(
        destination: URL,
        _ attributes: HTMLAttribute...,
        @HTMLBuilder label: () -> Label
    ) {
        self.destination = destination
        self.attributes = attributes
        self.label = label()
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
        self.attributes = attributes
        self.label = label
    }

    private var className: String {
        if buttonStyle == .automatic {
            return "swui-navigation-link"
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
                theme: theme,
                colorScheme: colorScheme,
                layoutDirection: layoutDirection,
                controlState: isEnabled ? .enabled : .disabled
            )
        )
    }

    private var linkAttributes: [HTMLAttribute] {
        var result = [HTMLAttribute("data-navigation-link", "true")]
        if isEnabled {
            result.append(.href(destination.relativeString))
        } else {
            result.append(.aria("disabled", "true"))
            result.append(.tabindex(-1))
            result.append(styleAttribute(.pointerEvents("none")))
        }
        return result
    }
}

public extension NavigationLink where Label == text {
    init(_ title: String, destination: URL, _ attributes: HTMLAttribute...) {
        self.init(destination: destination, attributes: attributes, label: text(title))
    }
}
