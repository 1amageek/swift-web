import SwiftHTML

private struct PickerSelectionEnvironmentKey: ClientEnvironmentKey {
    static let defaultValue: String? = nil
}

extension EnvironmentValues {
    var pickerSelection: String? {
        get { self[PickerSelectionEnvironmentKey.self] }
        set { self[PickerSelectionEnvironmentKey.self] = newValue }
    }
}

public struct PickerOption: WebUIAttributeComponent {
    private let value: String
    private let label: String
    private let attributes: [HTMLAttribute]

    @Environment(\.pickerSelection) private var pickerSelection

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
        Element(
            "option",
            attributes: mergedAttributes(extra: optionAttributes)
        ) {
            label
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
}
