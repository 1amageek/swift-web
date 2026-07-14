import SwiftWebUITheme
import SwiftHTML

public struct Spacer: AttributeComponent {
    private let minLength: Double?
    private let attributes: [HTMLAttribute]

    /// - Parameter minLength: The minimum length the spacer keeps along its
    ///   parent stack's axis, in points. The axis is resolved by the stylesheet
    ///   (`min-height` under a vertical stack, `min-width` under a horizontal
    ///   stack), so the same spacer works in both orientations. The value must
    ///   be finite: an infinite minimum length has no meaning.
    public init(minLength: Double? = nil, _ attributes: HTMLAttribute...) {
        if let minLength {
            precondition(minLength.isFinite, "Spacer minLength must be finite")
        }
        self.minLength = minLength
        self.attributes = attributes
    }

    @HTMLBuilder
    public var body: some HTML {
        Element("div", attributes: resolvedAttributes)
    }

    private var resolvedAttributes: [HTMLAttribute] {
        var result: [HTMLAttribute] = [.class("swui-spacer")]
        if let minLength {
            // Published as a custom property; the parent-axis-aware rules in
            // the root stylesheet lower it onto min-width or min-height.
            result.append(styleAttribute(.custom("--swui-spacer-min-length", pixelValue(minLength))))
        }
        return mergedAttributes(extra: result + attributes)
    }

    public func addingAttributes(_ attributes: [HTMLAttribute]) -> Self {
        Self(minLength: minLength, attributes: self.attributes + attributes)
    }

    private init(minLength: Double?, attributes: [HTMLAttribute]) {
        self.minLength = minLength
        self.attributes = attributes
    }
}
