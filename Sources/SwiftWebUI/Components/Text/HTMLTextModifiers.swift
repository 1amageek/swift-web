import SwiftHTML

public extension WebUIAttributeMutableHTML {
    func font(_ font: Font) -> AttributeAppliedContent<Self> {
        applyingAttributes([styleAttribute(font.style)])
    }

    func fontWeight(_ weight: FontWeight) -> AttributeAppliedContent<Self> {
        applyingAttributes([styleAttribute(.fontWeight(weight.cssValue))])
    }

    func fontDesign(_ design: FontDesign) -> AttributeAppliedContent<Self> {
        applyingAttributes([styleAttribute(.fontFamily(design.cssValue))])
    }

    func bold() -> AttributeAppliedContent<Self> {
        fontWeight(.bold)
    }

    func italic() -> AttributeAppliedContent<Self> {
        applyingAttributes([styleAttribute(.fontStyle("italic"))])
    }

    func monospaced() -> AttributeAppliedContent<Self> {
        fontDesign(.monospaced)
    }
}

public extension HTML {
    func font(_ font: Font) -> ModifiedContent<Self, HTMLAttributeModifier> {
        modifier(HTMLAttributeModifier([styleAttribute(font.style)]))
    }

    func fontWeight(_ weight: FontWeight) -> ModifiedContent<Self, HTMLAttributeModifier> {
        modifier(HTMLAttributeModifier([styleAttribute(.fontWeight(weight.cssValue))]))
    }

    func fontDesign(_ design: FontDesign) -> ModifiedContent<Self, HTMLAttributeModifier> {
        modifier(HTMLAttributeModifier([styleAttribute(.fontFamily(design.cssValue))]))
    }

    func bold() -> ModifiedContent<Self, HTMLAttributeModifier> {
        fontWeight(.bold)
    }

    func italic() -> ModifiedContent<Self, HTMLAttributeModifier> {
        modifier(HTMLAttributeModifier([styleAttribute(.fontStyle("italic"))]))
    }

    func monospaced() -> ModifiedContent<Self, HTMLAttributeModifier> {
        fontDesign(.monospaced)
    }
}
