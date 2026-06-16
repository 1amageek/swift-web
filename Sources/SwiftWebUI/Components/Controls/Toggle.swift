import SwiftHTML

public struct Toggle: WebUIAttributeComponent {
    private let title: String
    private let isOn: Binding<Bool>?
    private let initialValue: Bool
    private let attributes: [HTMLAttribute]
    @Environment(\.controlSize) private var controlSize
    @Environment(\.isEnabled) private var isEnabled

    public init(
        _ title: String,
        isOn: Binding<Bool>,
        _ attributes: HTMLAttribute...
    ) {
        self.title = title
        self.isOn = isOn
        self.initialValue = isOn.wrappedValue
        self.attributes = attributes
    }

    @HTMLBuilder
    public var body: some HTML {
        Element("label", attributes: [.class("swui-toggle \(controlSize.className)")]) {
            Element("input", attributes: inputAttributes, isVoid: true)
            span(.class("swui-toggle-control")) {}
            span(.class("swui-toggle-label")) {
                title
            }
        }
    }

    public func addingAttributes(_ attributes: [HTMLAttribute]) -> Self {
        Self(title: title, isOn: isOn, initialValue: initialValue, attributes: self.attributes + attributes)
    }

    private init(title: String, isOn: Binding<Bool>?, initialValue: Bool, attributes: [HTMLAttribute]) {
        self.title = title
        self.isOn = isOn
        self.initialValue = initialValue
        self.attributes = attributes
    }

    private var inputAttributes: [HTMLAttribute] {
        var result: [HTMLAttribute] = [
            .class("swui-toggle-input"),
            .type(.checkbox),
        ]
        if !isEnabled {
            result.append(.disabled)
            result.append(.aria("disabled", "true"))
        }
        if let isOn {
            result.append(.checked(isOn))
            result.append(.onChange { event in
                isOn.wrappedValue = event.checked ?? false
            })
        } else if initialValue {
            result.append(.checked)
        }
        result.append(contentsOf: attributes)
        return result
    }
}
