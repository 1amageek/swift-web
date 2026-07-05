import SwiftWebUITheme
import SwiftHTML

public struct Button<Label: HTML>: WebUIAttributeComponent {
    private let attributes: [HTMLAttribute]
    private let action: (any ActionRepresentable)?
    private let label: Label
    @Environment(\.theme) private var theme: Theme
    @Environment(\.colorScheme) private var colorScheme: ColorScheme
    @Environment(\.layoutDirection) private var layoutDirection: LayoutDirection
    @Environment(\.controlSize) private var controlSize: ControlSize
    @Environment(\.isEnabled) private var isEnabled: Bool
    @Environment(\.tint) private var tint: Color?
    @Environment(\.buttonStyle) private var buttonStyle: ButtonStyleKind
    @Environment(\.isInsideForm) private var isInsideForm: Bool

    public init(
        @HTMLBuilder label: () -> Label
    ) {
        self.attributes = [.type(ButtonType.button)]
        self.action = nil
        self.label = label()
    }

    public init(
        action: @escaping @Sendable () -> Void,
        @HTMLBuilder label: () -> Label
    ) {
        self.attributes = [.type(ButtonType.button), .onClick(action)]
        self.action = nil
        self.label = label()
    }

    public init(
        action: any ActionRepresentable,
        @HTMLBuilder label: () -> Label
    ) {
        self.attributes = []
        self.action = action
        self.label = label()
    }

    public init(
        action: ButtonAction,
        @HTMLBuilder label: () -> Label
    ) {
        self.init(
            action: action as any ActionRepresentable,
            label: label
        )
    }

    @HTMLBuilder
    public var body: some HTML {
        if let action {
            if isInsideForm {
                actionButton(action)
            } else {
                standaloneActionForm(action)
            }
        } else {
            Element(
                "button",
                attributes: mergedAttributes(
                    class: buttonClassName,
                    styles: buttonStyleValue,
                    extra: disabledAttributes + attributes
                )
            ) {
                label
            }
        }
    }

    public func addingAttributes(_ attributes: [HTMLAttribute]) -> Self {
        Self(
            attributes: self.attributes + attributes,
            action: action,
            label: label
        )
    }

    private init(
        attributes: [HTMLAttribute],
        action: (any ActionRepresentable)?,
        label: Label
    ) {
        self.attributes = attributes
        self.action = action
        self.label = label
    }

    private var styleConfiguration: ButtonStyleConfiguration {
        // Prominence is expressed through `.buttonStyle(...)` (e.g.
        // `.borderedProminent`), matching SwiftUI. The configuration's
        // prominence stays at the non-prominent baseline so the `.automatic`
        // style resolves to the bordered treatment.
        ButtonStyleConfiguration(
            prominence: .secondary,
            controlSize: controlSize,
            isEnabled: isEnabled,
            tint: tint?.cssValue
        )
    }

    private var styleContext: StyleResolutionContext {
        StyleResolutionContext(
            theme: theme,
            colorScheme: colorScheme,
            layoutDirection: layoutDirection,
            controlState: isEnabled ? .enabled : .disabled
        )
    }

    private var styleResult: ButtonStyleResult {
        buttonStyle.resolve(
            configuration: styleConfiguration,
            context: styleContext
        )
    }

    private var buttonClassName: String {
        styleResult.classNames.joined(separator: " ")
    }

    private var buttonStyleValue: Style {
        styleResult.style
    }

    private var disabledAttributes: [HTMLAttribute] {
        isEnabled ? [] : [.disabled, .aria("disabled", "true")]
    }

    @HTMLBuilder
    private func standaloneActionForm(_ action: any ActionRepresentable) -> some HTML {
        Form(
            action: action.path,
            method: action.method,
            HTMLAttribute("data-server-action", "true")
        ) {
            for field in action.fields {
                hiddenInput(field)
            }
            if action.method == .post {
                ButtonActionHiddenFields(excluding: action.fields.map(\.name))
            }
            actionButton(action)
        }
        .class("swui-button-action-form")
    }

    @HTMLBuilder
    private func actionButton(_ action: any ActionRepresentable) -> some HTML {
        Element(
            "button",
            attributes: mergedAttributes(
                class: buttonClassName,
                styles: buttonStyleValue,
                extra: actionButtonAttributes(action) + disabledAttributes + attributes
            )
        ) {
            label
        }
    }

    private func hiddenInput(_ field: ActionField) -> Element {
        Element(
            "input",
            attributes: [
                .type(InputType.hidden),
                .name(field.name),
                .value(field.value),
            ],
            isVoid: true
        )
    }

    private func actionButtonAttributes(_ action: any ActionRepresentable) -> [HTMLAttribute] {
        var attributes: [HTMLAttribute] = [
            .type(ButtonType.submit),
            .formaction(action.path),
            .formmethod(action.method),
            HTMLAttribute("data-server-action-button", "true"),
        ]

        if action.fields.count == 1, let field = action.fields.first {
            attributes.append(.name(field.name))
            attributes.append(.value(field.value))
        } else if !action.fields.isEmpty {
            attributes.append(HTMLAttribute("data-action-field-count", String(action.fields.count)))
            for (index, field) in action.fields.enumerated() {
                attributes.append(HTMLAttribute("data-action-field-\(index)-name", field.name))
                attributes.append(HTMLAttribute("data-action-field-\(index)-value", field.value))
            }
        }

        return attributes
    }
}

private struct ButtonActionHiddenFields: ServerComponent {
    let excludedNames: [String]
    @Environment(\.actionHiddenFields) private var actionHiddenFields: [ActionField]

    init(excluding excludedNames: [String]) {
        self.excludedNames = excludedNames
    }

    @HTMLBuilder
    var body: some HTML {
        for field in actionHiddenFields {
            if !excludedNames.contains(field.name) {
                Element(
                    "input",
                    attributes: [
                        .type(InputType.hidden),
                        .name(field.name),
                        .value(field.value),
                    ],
                    isVoid: true
                )
            }
        }
    }
}

public extension Button where Label == text {
    init(_ title: String) {
        self.init {
            title
        }
    }

    init(
        _ title: String,
        action: @escaping @Sendable () -> Void
    ) {
        self.init(action: action) {
            title
        }
    }

    init(
        _ title: String,
        action: any ActionRepresentable
    ) {
        self.init(action: action) {
            title
        }
    }

    init(
        _ title: String,
        action: ButtonAction
    ) {
        self.init(action: action) {
            title
        }
    }
}
