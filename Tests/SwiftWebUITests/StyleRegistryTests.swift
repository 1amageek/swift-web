import Testing
import SwiftHTML
import SwiftWebUI
import SwiftWebStyle

@Suite struct StyleRegistryTests {
    @Test func classNameIsDeterministicAndUnitAware() {
        #expect(
            StyleRegistry.className(property: "width", value: "237px")
            == StyleRegistry.className(property: "width", value: "237px")
        )
        // unit must be part of the key: 13px and 13em are different classes
        #expect(
            StyleRegistry.className(property: "border-radius", value: "13px")
            != StyleRegistry.className(property: "border-radius", value: "13em")
        )
    }

    @Test func rejectsInjectingValues() {
        #expect(StyleRegistry.isSafe(property: "width", value: "237px"))
        #expect(StyleRegistry.isSafe(property: "--swui-w", value: "237px"))
        // a value that would close the rule and inject a new selector
        #expect(!StyleRegistry.isSafe(property: "width", value: "1px} body{display:none}"))
        #expect(!StyleRegistry.isSafe(property: "color", value: "red; } x{color:blue"))
        #expect(!StyleRegistry.isSafe(property: "width", value: "100px/*x*/"))
    }

    @Test func typedDeclarationsPreserveUnsafeSemicolonValue() {
        let style = Style.custom("color", "red; background: blue")
        #expect(style.declarations.count == 1)
        let declaration = style.declarations[0]
        #expect(declaration.property == "color")
        #expect(declaration.value == "red; background: blue")
        #expect(!StyleRegistry.isSafe(property: declaration.property, value: declaration.value))
        #expect(!StyleRegistry.isSafe(style))
    }

    @Test func genericPropertyPrefixesDoNotCollide() {
        #expect(
            StyleRegistry.className(property: "--a-b", value: "1px")
            != StyleRegistry.className(property: "--ab", value: "1px")
        )
    }

    @Test func registerDeduplicatesAndReturnsClasses() {
        let registry = StyleRegistry()
        let first = registry.register(Style.custom("opacity", "0.6"))
        let second = registry.register(Style.custom("opacity", "0.6"))
        #expect(first == second)                 // same declaration -> same class
        #expect(registry.rules().count == 1)     // deduplicated
    }

    @Test func atomEmitsAClassAttributeWithinAScope() {
        let registry = StyleRegistry()
        StyleRegistry.withCurrent(registry) {
            let attribute = atom(Style.custom("opacity", "0.6"))
            #expect(attribute.name == "class")
            #expect(registry.rules().count == 1)
        }
    }

    @Test func typedStyleAttributesAreAtomizedByMergedAttributesBackstop() {
        let registry = StyleRegistry()
        let rendered = StyleRegistry.withCurrent(registry) {
            Spacer(minLength: 12).render()
        }
        #expect(!rendered.contains("style=\""))
        #expect(rendered.contains("class=\"swui-spacer swui-minw-12px-"))
        #expect(registry.rules().contains { $0.body == "min-width: 12px" })
    }
}
