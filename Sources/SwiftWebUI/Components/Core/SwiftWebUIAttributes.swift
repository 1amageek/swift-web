import SwiftWebUITheme
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
    // Every SwiftWebUI component and style modifier funnels through here, so
    // this is where a render declares that the response document needs the
    // SwiftWebUI bootstrap (root stylesheet, scripts, root attributes).
    SwiftWebUIDocumentStyle.installIfNeeded()
    DocumentStyle.current?.requireBootstrap()

    var classTokens: [String] = []
    if let baseClass, !baseClass.isEmpty {
        classTokens.append(baseClass)
    }

    // Accumulate the base styles and any extra typed style attributes into ONE typed
    // Style. SwiftWeb renderers bind StyleRegistry, so this serializes as classes.
    // A string style attribute would carry no typed payload and trip the transformer.
    var combinedStyle = styles
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
                combinedStyle.append(style)
            } else {
                preconditionFailure("String style attributes are not supported by SwiftWebUI components")
            }
        default:
            remainingAttributes.append(attribute)
        }
    }

    var styleFallback: HTMLAttribute?
    if !combinedStyle.isEmpty {
        if let registry = StyleRegistry.current {
            classTokens.append(registry.register(combinedStyle))
        } else {
            StyleRegistry.validate(combinedStyle)
            styleFallback = .style(combinedStyle)
        }
    }

    var result: [HTMLAttribute] = []
    if !classTokens.isEmpty {
        result.append(.class(classTokens.joined(separator: " ")))
    }
    if let styleFallback {
        result.append(styleFallback)
    }
    result.append(contentsOf: remainingAttributes)
    return result
}
