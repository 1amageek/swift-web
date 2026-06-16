import SwiftHTML

/// A view that shows the progress toward completion of a task, mirroring
/// SwiftUI `ProgressView`.
///
/// A determinate progress (a non-nil `value`) lowers to a native `<progress>`
/// element; an indeterminate progress (no `value`) lowers to a circular spinner
/// driven by a CSS animation. The bar track composes the shared ultra-thin
/// material so its fill tracks the active design style.
public struct ProgressView: WebUIAttributeComponent {
    private let label: String?
    private let value: Double?
    private let total: Double
    private let attributes: [HTMLAttribute]

    /// Creates an indeterminate progress view with an optional label.
    public init(_ label: String? = nil) {
        self.label = label
        self.value = nil
        self.total = 1.0
        self.attributes = []
    }

    /// Creates a determinate progress view that completes when `value` reaches
    /// `total`. A nil `value` renders an indeterminate spinner.
    public init(_ label: String? = nil, value: Double?, total: Double = 1.0) {
        self.label = label
        self.value = value
        self.total = total
        self.attributes = []
    }

    private init(label: String?, value: Double?, total: Double, attributes: [HTMLAttribute]) {
        self.label = label
        self.value = value
        self.total = total
        self.attributes = attributes
    }

    @HTMLBuilder
    public var body: some HTML {
        Element(
            "div",
            attributes: mergedAttributes(
                class: "swui-progress",
                extra: attributes
            )
        ) {
            if let label {
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
                    ],
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
        Self(label: label, value: value, total: total, attributes: self.attributes + attributes)
    }

    private var indeterminateAttributes: [HTMLAttribute] {
        var result: [HTMLAttribute] = [
            .class("swui-progress-spinner"),
            .role("progressbar"),
            .aria("busy", "true"),
        ]
        if let label {
            result.append(.aria("label", label))
        }
        return result
    }
}
