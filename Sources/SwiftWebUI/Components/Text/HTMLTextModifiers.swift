import SwiftHTML

public extension HTML {
    func font(_ font: Font) -> ModifiedContent<Self, HTMLAttributeModifier> {
        modifier(HTMLAttributeModifier([styleAttribute(font.style)], role: .textStyle))
    }

    func font(_ font: Font?) -> ModifiedContent<Self, HTMLAttributeModifier> {
        guard let font else {
            return modifier(HTMLAttributeModifier([], role: .textStyle))
        }
        return self.font(font)
    }

    func fontWeight(_ weight: FontWeight) -> ModifiedContent<Self, HTMLAttributeModifier> {
        modifier(HTMLAttributeModifier([styleAttribute(.fontWeight(weight.cssValue))], role: .textStyle))
    }

    func fontWeight(_ weight: FontWeight?) -> ModifiedContent<Self, HTMLAttributeModifier> {
        guard let weight else {
            return modifier(HTMLAttributeModifier([], role: .textStyle))
        }
        return fontWeight(weight)
    }

    func fontDesign(_ design: FontDesign) -> ModifiedContent<Self, HTMLAttributeModifier> {
        modifier(HTMLAttributeModifier([styleAttribute(.fontFamily(design.cssValue))], role: .textStyle))
    }

    func fontDesign(_ design: FontDesign?) -> ModifiedContent<Self, HTMLAttributeModifier> {
        guard let design else {
            return modifier(HTMLAttributeModifier([], role: .textStyle))
        }
        return fontDesign(design)
    }

    func bold(_ isActive: Bool = true) -> ModifiedContent<Self, HTMLAttributeModifier> {
        isActive ? fontWeight(.bold) : modifier(HTMLAttributeModifier([], role: .textStyle))
    }

    func italic(_ isActive: Bool = true) -> ModifiedContent<Self, HTMLAttributeModifier> {
        modifier(HTMLAttributeModifier([
            styleAttribute(.fontStyle(isActive ? "italic" : "normal"))
        ], role: .textStyle))
    }

    func monospaced(_ isActive: Bool = true) -> ModifiedContent<Self, HTMLAttributeModifier> {
        isActive ? fontDesign(.monospaced) : modifier(HTMLAttributeModifier([], role: .textStyle))
    }
}
