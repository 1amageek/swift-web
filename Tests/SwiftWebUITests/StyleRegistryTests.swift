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

    @Test func styleClassesSupportUtilityClassTokens() {
        let hoverUtility = StyleClass("hover:bg-blue-500")
        let stylesheetRule = rule(hoverUtility) {
            .background("var(--swui-accent)")
        }
        let classes: StyleClassList = ["swui-vstack", "swui-gap-sm", "swui-gap-sm"]

        #expect(hoverUtility.attribute.value == "hover:bg-blue-500")
        #expect(stylesheetRule.cssText.contains(".hover\\3a bg-blue-500:hover"))
        #expect(stylesheetRule.cssText.contains("background: var(--swui-accent);"))
        #expect(classes.rawValue == "swui-vstack swui-gap-sm")
    }

    @Test func styleUtilityVariantsComposeSelectorsAndAtRules() {
        let stylesheet = rule(StyleClass("dark:md:hover:bg-accent")) {
            .background("var(--swui-accent)")
        }

        #expect(stylesheet.cssText.contains("@media (min-width: 768px)"))
        #expect(stylesheet.cssText.contains(".swui-root[data-color-scheme=\"dark\"] .dark\\3a md\\3a hover\\3a bg-accent:hover"))
        #expect(stylesheet.cssText.contains("background: var(--swui-accent);"))
    }

    @Test func styleUtilityStateVariantsMapToPseudoClasses() {
        let stylesheet = Stylesheet {
            rule(StyleClass("focus-visible:outline-accent")) {
                .outline("2px solid var(--swui-accent)")
            }
            rule(StyleClass("disabled:opacity-50")) {
                .opacity("0.5")
            }
            rule(StyleClass("checked:bg-accent")) {
                .background("var(--swui-accent)")
            }
        }

        #expect(stylesheet.cssText.contains(".focus-visible\\3a outline-accent:focus-visible"))
        #expect(stylesheet.cssText.contains(".disabled\\3a opacity-50:disabled"))
        #expect(stylesheet.cssText.contains(".checked\\3a bg-accent:checked"))
    }

    @Test func styleUtilityRelationshipAndAttributeVariantsComposeSelectors() {
        let stylesheet = Stylesheet {
            rule(StyleClass("group-hover:bg-accent")) {
                .background("var(--swui-accent)")
            }
            rule(StyleClass("group-hover/card:bg-accent")) {
                .background("var(--swui-accent)")
            }
            rule(StyleClass("peer-checked:opacity-100")) {
                .opacity("1")
            }
            rule(StyleClass("peer-checked/form:opacity-100")) {
                .opacity("1")
            }
            rule(StyleClass("data-open:block")) {
                .display("block")
            }
            rule(StyleClass("data-[state=open]:block")) {
                .display("block")
            }
            rule(StyleClass("aria-expanded:font-bold")) {
                .fontWeight("700")
            }
            rule(StyleClass("aria-[sort=ascending]:font-bold")) {
                .fontWeight("700")
            }
        }

        #expect(stylesheet.cssText.contains(".group:hover .group-hover\\3a bg-accent"))
        #expect(stylesheet.cssText.contains(".group\\2f card:hover"))
        #expect(stylesheet.cssText.contains(".peer:checked ~ .peer-checked\\3a opacity-100"))
        #expect(stylesheet.cssText.contains(".peer\\2f form:checked"))
        #expect(stylesheet.cssText.contains(".data-open\\3a block[data-open]"))
        #expect(stylesheet.cssText.contains("[data-state=\"open\"]"))
        #expect(stylesheet.cssText.contains(".aria-expanded\\3a font-bold[aria-expanded=\"true\"]"))
        #expect(stylesheet.cssText.contains("[aria-sort=\"ascending\"]"))
    }

    @Test func styleUtilityStructuralVariantsComposeSelectors() {
        let stylesheet = Stylesheet {
            rule(StyleClass("has-checked:ring-accent")) {
                .outline("2px solid var(--swui-accent)")
            }
            rule(StyleClass("not-disabled:opacity-100")) {
                .opacity("1")
            }
            rule(StyleClass("*:text-sm")) {
                .fontSize("0.875rem")
            }
            rule(StyleClass("before:block")) {
                .display("block")
            }
            rule(StyleClass("[&:nth-child(3)]:bg-accent")) {
                .background("var(--swui-accent)")
            }
        }

        #expect(stylesheet.cssText.contains(".has-checked\\3a ring-accent:has(:checked)"))
        #expect(stylesheet.cssText.contains(".not-disabled\\3a opacity-100:not(:disabled)"))
        #expect(stylesheet.cssText.contains(".\\2a \\3a text-sm > *"))
        #expect(stylesheet.cssText.contains(".before\\3a block::before"))
        #expect(stylesheet.cssText.contains(":nth-child(3)"))
    }

    @Test func styleUtilityContainerVariantsEmitContainerQueries() {
        let stylesheet = Stylesheet {
            rule(StyleClass("@md:bg-accent")) {
                .background("var(--swui-accent)")
            }
            rule(StyleClass("@max-md/sidebar:block")) {
                .display("block")
            }
            rule(StyleClass("@min-[475px]:grid")) {
                .display("grid")
            }
        }

        #expect(stylesheet.cssText.contains("@container (min-width: 768px)"))
        #expect(stylesheet.cssText.contains("@container sidebar (max-width: 767.98px)"))
        #expect(stylesheet.cssText.contains("@container (min-width: 475px)"))
    }

    @Test func styleUtilityRegistryEmitsArbitraryValueUtilities() {
        let stylesheet = Stylesheet {
            utility(StyleClass("hover:bg-[#316ff6]"))
            utility(StyleClass("md:grid-cols-[1fr_500px_2fr]"))
            utility(StyleClass("p-[calc(100%_-_1rem)]"))
        }

        #expect(stylesheet.cssText.contains(".hover\\3a bg-\\5b \\23 316ff6\\5d :hover"))
        #expect(stylesheet.cssText.contains("background: #316ff6;"))
        #expect(stylesheet.cssText.contains("@media (min-width: 768px)"))
        #expect(stylesheet.cssText.contains("grid-template-columns: 1fr 500px 2fr;"))
        #expect(stylesheet.cssText.contains("padding: calc(100% - 1rem);"))
    }

    @Test func styleUtilityRegistryAcceptsTypedCustomUtilities() {
        let registry = StyleUtilityRegistry(definitions: [
            .token("brand-card", style: .borderRadius("18px")),
            .arbitrary(prefix: "brand-gap", property: "gap") { value in
                .gap(value)
            },
        ])

        let stylesheet = Stylesheet {
            utility(StyleClass("hover:brand-card"), registry: registry)
            utility(StyleClass("brand-gap-[2rem]"), registry: registry)
        }

        #expect(stylesheet.cssText.contains(".hover\\3a brand-card:hover"))
        #expect(stylesheet.cssText.contains("border-radius: 18px;"))
        #expect(stylesheet.cssText.contains("gap: 2rem;"))
    }

    @Test func swiftWebUIUtilityRegistryEmitsTokenUtilitiesWithVariants() {
        let stylesheet = Stylesheet {
            utility(StyleClass("hover:swui-bg-accent"), registry: .swiftWebUI)
            utility(StyleClass("dark:swui-fg-secondary"), registry: .swiftWebUI)
        }

        #expect(stylesheet.cssText.contains(".hover\\3a swui-bg-accent:hover"))
        #expect(stylesheet.cssText.contains("background: var(--swui-accent);"))
        #expect(stylesheet.cssText.contains(".swui-root[data-color-scheme=\"dark\"] .dark\\3a swui-fg-secondary"))
        #expect(stylesheet.cssText.contains("color: var(--swui-text-muted);"))
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
