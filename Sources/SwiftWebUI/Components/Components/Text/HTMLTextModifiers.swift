import SwiftWebUITheme
import SwiftHTML

public extension Component {
    @_transparent
    func font(_ font: Font) -> ModifiedContent {
        modifier(HTMLAttributeModifier([styleAttribute(font.style)], role: .textStyle))
    }

    func font(_ font: Font?) -> ModifiedContent {
        guard let font else {
            return modifier(HTMLAttributeModifier([], role: .textStyle))
        }
        return self.font(font)
    }

    func fontWeight(_ weight: Font.Weight) -> ModifiedContent {
        modifier(HTMLAttributeModifier([styleAttribute(.fontWeight(weight.cssValue))], role: .textStyle))
    }

    func fontWeight(_ weight: Font.Weight?) -> ModifiedContent {
        guard let weight else {
            return modifier(HTMLAttributeModifier([], role: .textStyle))
        }
        return fontWeight(weight)
    }

    func fontDesign(_ design: Font.Design) -> ModifiedContent {
        modifier(HTMLAttributeModifier([styleAttribute(.fontFamily(design.cssValue))], role: .textStyle))
    }

    func fontDesign(_ design: Font.Design?) -> ModifiedContent {
        guard let design else {
            return modifier(HTMLAttributeModifier([], role: .textStyle))
        }
        return fontDesign(design)
    }

    func bold(_ isActive: Bool = true) -> ModifiedContent {
        isActive ? fontWeight(.bold) : modifier(HTMLAttributeModifier([], role: .textStyle))
    }

    func italic(_ isActive: Bool = true) -> ModifiedContent {
        modifier(HTMLAttributeModifier([
            styleAttribute(.fontStyle(isActive ? "italic" : "normal"))
        ], role: .textStyle))
    }

    func monospaced(_ isActive: Bool = true) -> ModifiedContent {
        isActive ? fontDesign(.monospaced) : modifier(HTMLAttributeModifier([], role: .textStyle))
    }
}
