import SwiftHTML

private struct PickerSelectionEnvironmentKey: ClientEnvironmentKey {
    static let defaultValue: String? = nil
}

// The shared radio-group `name`, carried from `Picker` to its `PickerOption`
// children when the picker lowers to a radio group. The change handler lives on
// the group container (change events bubble), so options only need the group
// name to be mutually exclusive natively.
private struct PickerGroupNameEnvironmentKey: ClientEnvironmentKey {
    static let defaultValue: String? = nil
}

extension EnvironmentValues {
    var pickerSelection: String? {
        get { self[PickerSelectionEnvironmentKey.self] }
        set { self[PickerSelectionEnvironmentKey.self] = newValue }
    }

    var pickerGroupName: String? {
        get { self[PickerGroupNameEnvironmentKey.self] }
        set { self[PickerGroupNameEnvironmentKey.self] = newValue }
    }
}

public struct PickerOption: WebUIAttributeComponent {
    private let value: String
    private let label: String
    private let attributes: [HTMLAttribute]

    @Environment(\.pickerSelection) private var pickerSelection
    @Environment(\.pickerStyle) private var pickerStyle
    @Environment(\.pickerGroupName) private var pickerGroupName
    @Environment(\.isEnabled) private var isEnabled

    public init(_ label: String, value: String, _ attributes: HTMLAttribute...) {
        self.label = label
        self.value = value
        self.attributes = attributes
    }

    public init(_ label: String, value: Int, _ attributes: HTMLAttribute...) {
        self.init(value: String(value), label: label, attributes: attributes)
    }

    @HTMLBuilder
    public var body: some HTML {
        if pickerStyle.usesRadioGroup {
            radioOption
        } else {
            Element(
                "option",
                attributes: mergedAttributes(extra: optionAttributes)
            ) {
                label
            }
        }
    }

    public func addingAttributes(_ attributes: [HTMLAttribute]) -> Self {
        Self(value: value, label: label, attributes: self.attributes + attributes)
    }

    private init(value: String, label: String, attributes: [HTMLAttribute]) {
        self.value = value
        self.label = label
        self.attributes = attributes
    }

    private var optionAttributes: [HTMLAttribute] {
        var result: [HTMLAttribute] = [.value(value)]
        if pickerSelection == value {
            result.append(.selected)
        }
        result.append(contentsOf: attributes)
        return result
    }

    @HTMLBuilder
    private var radioOption: some HTML {
        Element("label", attributes: [.class("swui-picker-segment")]) {
            Element(
                "input",
                attributes: [.class("swui-picker-segment-input")] + radioAttributes,
                isVoid: true
            )
            span(.class("swui-picker-segment-label")) {
                label
            }
        }
    }

    // The radio carries no change handler of its own: the change event bubbles
    // to the group container, where `Picker` reads the fired radio's value to
    // update the selection binding.
    private var radioAttributes: [HTMLAttribute] {
        var result: [HTMLAttribute] = [
            .type(InputType.radio),
            .value(value),
        ]
        if let pickerGroupName {
            result.append(.name(pickerGroupName))
        }
        if pickerSelection == value {
            result.append(.checked)
        }
        if !isEnabled {
            result.append(.disabled)
        }
        result.append(contentsOf: attributes)
        return result
    }
}
