import SwiftHTML

public struct Toggle: WebUIAttributeComponent {
    private let title: String
    private let isOn: Binding<Bool>?
    private let initialValue: Bool
    private let attributes: [HTMLAttribute]
    @Environment(\.controlSize) private var controlSize
    @Environment(\.isEnabled) private var isEnabled
    @Environment(\.toggleStyle) private var toggleStyle

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
        Element(
            "label",
            attributes: [.class(controlClassName("swui-toggle", toggleStyle.className, controlSize.className))]
        ) {
            Element("input", attributes: inputAttributes, isVoid: true)
            // The track composes the shared thin material for its fill, backdrop
            // blur, and rim; the thumb keeps the track's own `::after` overlay,
            // which is why the material recipe only ever uses `::before`. The
            // raised surface tint stays opaque so the recipe owns translucency.
            span(
                .class("swui-toggle-control \(MaterialClass.material) \(MaterialClass.thin)"),
                styleAttribute(.custom("--swui-material-tint", "var(--swui-surface-raised)"))
            ) {}
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
