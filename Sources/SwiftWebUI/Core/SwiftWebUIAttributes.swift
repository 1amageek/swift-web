import SwiftHTML

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
        styleValues.append(styles.cssText)
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
            if let value = attribute.value, !value.isEmpty {
                styleValues.append(value)
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
