import SwiftHTML

/// A view that shows the progress toward completion of a task, mirroring
/// SwiftUI `ProgressView`.
///
/// A determinate progress (a non-nil `value`) lowers to a native `<progress>`
/// element; an indeterminate progress (no `value`) lowers to a circular spinner
/// driven by a CSS animation. The bar track composes the shared ultra-thin
/// material so its fill tracks the active design style.
public struct ProgressView<Label: HTML>: WebUIAttributeComponent {
    private let label: Label
    private let showsLabel: Bool
    private let accessibilityLabel: String?
    private let value: Double?
    private let total: Double
    private let attributes: [HTMLAttribute]
    @Environment(\.progressViewStyle) private var progressViewStyle

    public init(
        value: Double?,
        total: Double = 1.0,
        @HTMLBuilder label: () -> Label
    ) {
        self.init(label: label(), showsLabel: true, accessibilityLabel: nil, value: value, total: total, attributes: [])
    }

    private init(
        label: Label,
        showsLabel: Bool,
        accessibilityLabel: String?,
        value: Double?,
        total: Double,
        attributes: [HTMLAttribute]
    ) {
        self.label = label
        self.showsLabel = showsLabel
        self.accessibilityLabel = accessibilityLabel
        self.value = value
        self.total = total
        self.attributes = attributes
    }

    @HTMLBuilder
    public var body: some HTML {
        Element(
            "div",
            attributes: mergedAttributes(
                class: controlClassName("swui-progress", progressViewStyle.className),
                extra: attributes
            )
        ) {
            if showsLabel {
                span(.class("swui-progress-label")) {
                    label
                }
            }
            if let value {
                // `<progress>` is a replaced element: the material's `::before`
                // rim/refraction overlay does not paint here, but its fill and
                // backdrop blur (the track) still apply.
                Element(
                    "progress",
                    attributes: [
                        .class("swui-progress-bar \(MaterialClass.material) \(MaterialClass.ultraThin)"),
                        styleAttribute(.custom("--swui-material-tint", "var(--swui-field-background)")),
                        .value(value),
                        .max(total),
                    ] + accessibilityAttributes,
                    isVoid: false
                ) {}
            } else {
                Element(
                    "div",
                    attributes: indeterminateAttributes
                ) {}
            }
        }
    }

    public func addingAttributes(_ attributes: [HTMLAttribute]) -> Self {
        Self(
            label: label,
            showsLabel: showsLabel,
            accessibilityLabel: accessibilityLabel,
            value: value,
            total: total,
            attributes: self.attributes + attributes
        )
    }

    private var indeterminateAttributes: [HTMLAttribute] {
        [
            .class("swui-progress-spinner"),
            .role("progressbar"),
            .aria("busy", "true"),
        ] + accessibilityAttributes
    }

    private var accessibilityAttributes: [HTMLAttribute] {
        guard let accessibilityLabel else {
            return []
        }
        return [.aria("label", accessibilityLabel)]
    }
}

public extension ProgressView where Label == EmptyHTML {
    init() {
        self.init(label: EmptyHTML(), showsLabel: false, accessibilityLabel: nil, value: nil, total: 1.0, attributes: [])
    }

    init(value: Double?, total: Double = 1.0) {
        self.init(label: EmptyHTML(), showsLabel: false, accessibilityLabel: nil, value: value, total: total, attributes: [])
    }
}

public extension ProgressView where Label == text {
    init(_ title: String) {
        self.init(label: text(title), showsLabel: true, accessibilityLabel: title, value: nil, total: 1.0, attributes: [])
    }

    init(_ title: String, value: Double?, total: Double = 1.0) {
        self.init(label: text(title), showsLabel: true, accessibilityLabel: title, value: value, total: total, attributes: [])
    }
}
