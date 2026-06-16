import SwiftHTML

public struct Button<Label: HTML>: WebUIAttributeComponent {
    private let prominence: ButtonProminence
    private let attributes: [HTMLAttribute]
    private let action: (any ActionRepresentable)?
    private let label: Label
    @Environment(\.actionHiddenFields) private var actionHiddenFields
    @Environment(\.theme) private var theme
    @Environment(\.styleSystem) private var styleSystem
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.layoutDirection) private var layoutDirection
    @Environment(\.controlSize) private var controlSize
    @Environment(\.isEnabled) private var isEnabled
    @Environment(\.tint) private var tint
    @Environment(\.buttonStyle) private var buttonStyle
    @Environment(\.isInsideForm) private var isInsideForm

    public init(
        prominence: ButtonProminence = .secondary,
        @HTMLBuilder label: () -> Label
    ) {
        self.prominence = prominence
        self.attributes = [.type(ButtonType.button)]
        self.action = nil
        self.label = label()
    }

    public init(
        action: @escaping () -> Void,
        prominence: ButtonProminence = .secondary,
        @HTMLBuilder label: () -> Label
    ) {
        self.prominence = prominence
        self.attributes = [.type(ButtonType.button), .onClick(action)]
        self.action = nil
        self.label = label()
    }

    public init(
        action: any ActionRepresentable,
        prominence: ButtonProminence = .secondary,
        @HTMLBuilder label: () -> Label
    ) {
        self.prominence = prominence
        self.attributes = []
        self.action = action
        self.label = label()
    }

    public init(
        action: ButtonAction,
        prominence: ButtonProminence = .secondary,
        @HTMLBuilder label: () -> Label
    ) {
        self.init(
            action: action as any ActionRepresentable,
            prominence: prominence,
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
            prominence: prominence,
            attributes: self.attributes + attributes,
            action: action,
            label: label
        )
    }

    private init(
        prominence: ButtonProminence,
        attributes: [HTMLAttribute],
        action: (any ActionRepresentable)?,
        label: Label
    ) {
        self.prominence = prominence
        self.attributes = attributes
        self.action = action
        self.label = label
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
            HTMLAttribute("data-swift-server-action", "true")
        ) {
            for field in action.fields {
                hiddenInput(field)
            }
            if action.method == .post {
                for field in actionHiddenFields {
                    if !action.fields.contains(where: { $0.name == field.name }) {
                        hiddenInput(field)
                    }
                }
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
            HTMLAttribute("data-swift-server-action-button", "true"),
        ]

        if action.fields.count == 1, let field = action.fields.first {
            attributes.append(.name(field.name))
            attributes.append(.value(field.value))
        } else if !action.fields.isEmpty {
            attributes.append(HTMLAttribute("data-swift-action-field-count", String(action.fields.count)))
            for (index, field) in action.fields.enumerated() {
                attributes.append(HTMLAttribute("data-swift-action-field-\(index)-name", field.name))
                attributes.append(HTMLAttribute("data-swift-action-field-\(index)-value", field.value))
            }
        }

        return attributes
    }
}

public extension Button where Label == text {
    init(
        _ title: String,
        prominence: ButtonProminence = .secondary
    ) {
        self.init(prominence: prominence) {
            title
        }
    }

    init(
        _ title: String,
        prominence: ButtonProminence = .secondary,
        action: @escaping () -> Void
    ) {
        self.init(action: action, prominence: prominence) {
            title
        }
    }

    init(
        _ title: String,
        action: any ActionRepresentable,
        prominence: ButtonProminence = .secondary
    ) {
        self.init(action: action, prominence: prominence) {
            title
        }
    }

    init(
        _ title: String,
        action: ButtonAction,
        prominence: ButtonProminence = .secondary
    ) {
        self.init(action: action, prominence: prominence) {
            title
        }
    }
}
