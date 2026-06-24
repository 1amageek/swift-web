import SwiftHTML
import SwiftWebStyle

/// The `--swui-control-tint` declaration for a tintable control, emitted only
/// when a `.tint(...)` is in scope. Page renders atomize it into a class; when
/// absent, the control's CSS resolves `var(--swui-control-tint, <style-system token>)`
/// to its style-system default rather than an environment-supplied override.
func controlTintStyle(_ tint: String?) -> Style {
    guard let tint else { return Style() }
    return .custom("--swui-control-tint", tint)
}

func mergedAttributes(
    class baseClass: String? = nil,
    styles: Style = Style(),
    extra attributes: [HTMLAttribute]
) -> [HTMLAttribute] {
    var classTokens: [String] = []
    if let baseClass, !baseClass.isEmpty {
        classTokens.append(baseClass)
    }

    var styleValues: [String] = []
    if !styles.isEmpty {
        // Atomize the component's base styles into classes; inline only outside a
        // render scope (an isolated render). See docs/AtomicStyling.md.
        if let registry = StyleRegistry.current {
            classTokens.append(registry.register(styles))
        } else {
            StyleRegistry.validate(styles)
            styleValues.append(styles.cssText)
        }
    }
    var remainingAttributes: [HTMLAttribute] = []
    remainingAttributes.reserveCapacity(attributes.count)

    for attribute in attributes {
        switch attribute.name {
        case "class":
            if let value = attribute.value, !value.isEmpty {
                classTokens.append(value)
            }
        case "style":
            if let style = attribute.style {
                if let registry = StyleRegistry.current {
                    let className = registry.register(style)
                    if !className.isEmpty {
                        classTokens.append(className)
                    }
                } else if let value = attribute.value, !value.isEmpty {
                    StyleRegistry.validate(style)
                    styleValues.append(value)
                }
            } else {
                preconditionFailure("String style attributes are not supported by SwiftWebUI components")
            }
        default:
            remainingAttributes.append(attribute)
        }
    }

    var result: [HTMLAttribute] = []
    if !classTokens.isEmpty {
        result.append(.class(classTokens.joined(separator: " ")))
    }
    if !styleValues.isEmpty {
        result.append(HTMLAttribute(name: "style", value: styleValues.joined(separator: "; "), kind: .string))
    }
    result.append(contentsOf: remainingAttributes)
    return result
}
