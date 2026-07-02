import SwiftWebUITheme
import SwiftHTML

public extension HTML {
    /// Fill the surface with a `Material`, edge to edge.
    ///
    /// Mirrors SwiftUI `background(_:)` with a material: without a shape the
    /// surface keeps square corners and covers the view's full bounds.
    func background(_ material: Material) -> ModifiedContent<Self, HTMLAttributeModifier> {
        modifier(HTMLAttributeModifier([.class(material.classNames.joined(separator: " "))]))
    }

    /// Fill the surface with a `Material`, clipped to `shape`.
    ///
    /// Mirrors SwiftUI `background(_:in:)`. The material owns the fill and
    /// backdrop recipe; the shape only contributes the `border-radius` that
    /// clips the surface and its `backdrop-filter`.
    func background(_ material: Material, in shape: Shape) -> ModifiedContent<Self, HTMLAttributeModifier> {
        modifier(HTMLAttributeModifier(materialSurfaceAttributes(classNames: material.classNames, shape: shape)))
    }

    /// Apply a Liquid Glass effect, clipped to `shape`.
    ///
    /// Mirrors SwiftUI `glassEffect(_:in:)`. `Glass.identity` is a no-op.
    func glassEffect(_ glass: Glass = .regular, in shape: Shape = .capsule) -> ModifiedContent<Self, HTMLAttributeModifier> {
        guard let attributes = glass.attributes(in: shape) else {
            return modifier(HTMLAttributeModifier([]))
        }
        return modifier(HTMLAttributeModifier(attributes))
    }
}

/// Build the attributes a material surface contributes: the class tokens plus
/// the shape's clipping radius.
func materialSurfaceAttributes(classNames: [String], shape: Shape) -> [HTMLAttribute] {
    [
        .class(classNames.joined(separator: " ")),
        styleAttribute(Style.borderRadius(shape.cornerRadiusValue)),
    ]
}
