import SwiftWebUITheme
import SwiftHTML

public struct Toggle<Label: HTML>: AttributeComponent {
    private let label: Label
    private let isOn: Binding<Bool>?
    private let initialValue: Bool
    private let attributes: [HTMLAttribute]
    @Environment({ $0.controlSize }) private var controlSize: ControlSize
    @Environment({ $0.isEnabled }) private var isEnabled: Bool
    @Environment({ $0.toggleStyle }) private var toggleStyle: ToggleStyleKind

    public init(
        isOn: Binding<Bool>,
        _ attributes: HTMLAttribute...,
        @HTMLBuilder label: () -> Label
    ) {
        self.label = label()
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
            // The track composes the shared thin material for its fill and
            // backdrop blur; the thumb is a real Liquid Glass child so the
            // per-element refraction script can target it (a `::after` overlay
            // is unreachable from `querySelectorAll`). The raised surface tint
            // stays opaque so the recipe owns the track's translucency, while
            // the thumb refracts the track and backdrop through its rim.
            span(
                .class("swui-toggle-control \(MaterialClass.material) \(MaterialClass.thin)"),
                styleAttribute(.custom("--swui-material-tint", "var(--swui-surface-raised)"))
            ) {
                span(.class("swui-toggle-thumb \(MaterialClass.glass)")) {}
            }
            span(.class("swui-toggle-label")) {
                label
            }
        }
    }

    public func addingAttributes(_ attributes: [HTMLAttribute]) -> Self {
        Self(
            label: label,
            isOn: isOn,
            initialValue: initialValue,
            attributes: self.attributes + attributes
        )
    }

    private init(
        label: Label,
        isOn: Binding<Bool>?,
        initialValue: Bool,
        attributes: [HTMLAttribute]
    ) {
        self.label = label
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

public extension Toggle where Label == text {
    init(
        _ title: String,
        isOn: Binding<Bool>,
        _ attributes: HTMLAttribute...
    ) {
        self.init(label: text(title), isOn: isOn, initialValue: isOn.wrappedValue, attributes: attributes)
    }
}
