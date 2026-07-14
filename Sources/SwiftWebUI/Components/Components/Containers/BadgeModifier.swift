import SwiftWebUITheme
import SwiftHTML

public extension HTML {
    /// Displays a trailing badge next to this view, mirroring SwiftUI's
    /// `badge(_:)`. Passing `nil` or an empty string shows no badge.
    ///
    /// The wrapper is layout-transparent (`display: contents`), so inside a
    /// list row or any horizontal flow the pill sits at the trailing edge.
    @HTMLBuilder
    func badge(_ label: String?) -> some HTML {
        if let label, !label.isEmpty {
            Element(
                "div",
                attributes: mergedAttributes(class: "swui-badged", extra: [])
            ) {
                self
                BadgePill(label)
            }
        } else {
            self
        }
    }

    /// Displays a trailing numeric badge; `0` hides the badge, matching
    /// SwiftUI's count semantics.
    func badge(_ count: Int) -> some HTML {
        badge(count == 0 ? nil : String(count))
    }
}

/// The badge pill: a thin-material capsule that picks up the active design
/// style's backdrop blur, rim, and refraction. The semantic raised surface
/// stays a per-badge difference, fed in through `.tint(...)` when present.
struct BadgePill: Component {
    @Environment({ $0.tint }) private var tint: Color?

    private let text: String
    private let attributes: [HTMLAttribute]

    init(_ text: String, attributes: [HTMLAttribute] = []) {
        self.text = text
        self.attributes = attributes
    }

    @HTMLBuilder
    var body: some HTML {
        Element(
            "span",
            attributes: mergedAttributes(
                class: "swui-badge \(MaterialClass.material) \(MaterialClass.thin)",
                styles: controlTintStyle(tint?.cssValue)
                    .custom("--swui-material-tint", "var(--swui-control-tint, var(--swui-badge-background))"),
                extra: attributes
            )
        ) {
            text
        }
    }
}
