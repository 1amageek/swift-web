import Testing
import SwiftHTML
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

    @Test func registerDeduplicatesAndReturnsClasses() {
        let registry = StyleRegistry()
        let first = registry.register(Style.custom("opacity", "0.6"))
        let second = registry.register(Style.custom("opacity", "0.6"))
        #expect(first == second)                 // same declaration -> same class
        #expect(registry.rules().count == 1)     // deduplicated
    }

    @Test func atomEmitsAClassAttributeWithinAScope() {
        let registry = StyleRegistry()
        StyleRegistry.$current.withValue(registry) {
            let attribute = atom(Style.custom("opacity", "0.6"))
            #expect(attribute.name == "class")
            #expect(registry.rules().count == 1)
        }
    }
}
