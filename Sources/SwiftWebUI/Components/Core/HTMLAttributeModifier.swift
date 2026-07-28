import SwiftWebUITheme
import SwiftHTML

@usableFromInline
enum HTMLModifierRole: Sendable, Equatable {
    case box
    case textStyle
    case semantic

    var className: String {
        switch self {
        case .box:
            "swui-box-modifier"
        case .textStyle:
            "swui-text-style-modifier"
        case .semantic:
            "swui-semantic-modifier"
        }
    }
}

public struct HTMLAttributeModifier: ComponentModifier {
    private let attributes: [HTMLAttribute]
    private let role: HTMLModifierRole

    @usableFromInline
    init(_ attributes: [HTMLAttribute], role: HTMLModifierRole = .box) {
        self.attributes = attributes
        self.role = role
    }

    @ComponentBuilder
    public func content(_ content: ModifierContent) -> some Component {
        Element(
            "div",
            attributes: mergedAttributes(
                class: "swui-modifier swui-attribute \(role.className)",
                extra: attributes
            )
        ) {
            content
        }
    }
}

public extension Component {
    /// Sets a plain HTML attribute on the content's rendered root element,
    /// for contracts expressed as data attributes (e.g. WebMapKit's
    /// `data-mapkit-select` selection triggers) and ARIA annotations.
    ///
    /// Attaches via `RootAttributes` — no wrapper node is introduced, so
    /// parent CSS contracts (grid/flex children, direct-child selectors)
    /// are preserved.
    func attribute(_ name: String, _ value: String? = nil) -> some Component {
        RootAttributes([.attribute(name, value)]) { self }
    }
}
