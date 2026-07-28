import SwiftWebUITheme
import SwiftHTML

/// Groups Liquid Glass surfaces into one shared compositing context.
///
/// Mirrors SwiftUI's `GlassEffectContainer(spacing:content:)`. Establishing an
/// `isolation: isolate` stacking context lets grouped glass surfaces sample a
/// common backdrop and keeps their refraction/rim layers from bleeding into
/// surrounding content. Morph-merge between adjacent glass shapes is a future
/// extension; for now the container provides the shared context and spacing.
public struct GlassEffectContainer<Content: Component>: AttributeComponent {
    private let spacing: Space?
    private let attributes: [HTMLAttribute]
    private let childContent: Content

    public init(
        spacing: Space? = nil,
        _ attributes: HTMLAttribute...,
        @HTMLBuilder content: () -> Content
    ) {
        self.spacing = spacing
        self.attributes = attributes
        self.childContent = content()
    }

    @ComponentBuilder
    public var content: some Component {
        Element(
            "div",
            attributes: mergedAttributes(
                class: MaterialClass.container,
                styles: containerStyle,
                extra: attributes
            )
        ) {
            childContent
        }
    }

    private var containerStyle: Style {
        guard let spacing else {
            return Style()
        }
        return .gap(spacing.rawValue)
    }

    public func addingAttributes(_ attributes: [HTMLAttribute]) -> Self {
        Self(spacing: spacing, attributes: self.attributes + attributes, content: childContent)
    }

    private init(spacing: Space?, attributes: [HTMLAttribute], content: Content) {
        self.spacing = spacing
        self.attributes = attributes
        self.childContent = content
    }
}
