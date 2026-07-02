import SwiftWebUITheme
import SwiftHTML

/// A concrete shape descriptor used to clip a material/glass surface.
///
/// SwiftWebUI does not solve geometry on the Swift side; a shape only resolves
/// to a CSS `border-radius` value, which the browser applies to the surface and
/// which in turn clips the surface's `backdrop-filter`. The vocabulary mirrors
/// SwiftUI's `Shape` shorthands (`.capsule`, `.circle`, `.rect(cornerRadius:)`).
public struct Shape: Sendable, Equatable {
    enum Kind: Sendable, Equatable {
        case capsule
        case circle
        case rect(cornerRadius: Length)
    }

    let kind: Kind

    init(kind: Kind) {
        self.kind = kind
    }

    /// A pill: fully rounded ends. Maps to the root pill radius.
    public static let capsule = Shape(kind: .capsule)

    /// A circle. Maps to `border-radius: 50%`.
    public static let circle = Shape(kind: .circle)

    /// A rectangle using the root medium corner radius.
    public static let rect = Shape(kind: .rect(cornerRadius: .custom("var(--swui-radius-medium)")))

    /// A rounded rectangle with an explicit corner radius.
    public static func rect(cornerRadius: Length) -> Shape {
        Shape(kind: .rect(cornerRadius: cornerRadius))
    }

    /// The CSS `border-radius` value this shape resolves to.
    var cornerRadiusValue: String {
        switch kind {
        case .capsule:
            "var(--swui-radius-pill)"
        case .circle:
            "50%"
        case .rect(let cornerRadius):
            cornerRadius.cssValue
        }
    }
}
