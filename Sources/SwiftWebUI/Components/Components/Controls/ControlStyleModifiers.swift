import SwiftWebUITheme
import SwiftHTML

public enum ToggleStyleKind: String, Sendable, Equatable {
    case automatic
    case `switch`
    case checkbox
    case button
}

public enum TextFieldStyleKind: String, Sendable, Equatable {
    case automatic
    case plain
    case roundedBorder
    case squareBorder
}

public enum LabelStyleKind: String, Sendable, Equatable {
    case automatic
    case titleAndIcon
    case titleOnly
    case iconOnly
}

public enum ListStyleKind: String, Sendable, Equatable {
    case automatic
    case plain
    case inset
    case grouped
    case insetGrouped
    case sidebar
}

public enum FormStyleKind: String, Sendable, Equatable {
    case automatic
    case grouped
    case columns
}

public enum MenuStyleKind: String, Sendable, Equatable {
    case automatic
    case button
    case borderlessButton
}

public enum ProgressViewStyleKind: String, Sendable, Equatable {
    case automatic
    case linear
    case circular
}

public enum GaugeStyleKind: String, Sendable, Equatable {
    case automatic
    case linearCapacity
    case accessoryCircular
    case accessoryLinear
}

public enum TabViewStyleKind: String, Sendable, Equatable {
    case automatic
    case tabBar
    case page
}

public extension HTML {
    func toggleStyle(_ style: ToggleStyleKind) -> some HTML {
        transformEnvironment({ $0.toggleStyle = style })
    }

    func textFieldStyle(_ style: TextFieldStyleKind) -> some HTML {
        transformEnvironment({ $0.textFieldStyle = style })
    }

    func labelStyle(_ style: LabelStyleKind) -> some HTML {
        transformEnvironment({ $0.labelStyle = style })
    }

    func listStyle(_ style: ListStyleKind) -> some HTML {
        transformEnvironment({ $0.listStyle = style })
    }

    func formStyle(_ style: FormStyleKind) -> some HTML {
        transformEnvironment({ $0.formStyle = style })
    }

    func menuStyle(_ style: MenuStyleKind) -> some HTML {
        transformEnvironment({ $0.menuStyle = style })
    }

    func progressViewStyle(
        _ style: ProgressViewStyleKind
    ) -> some HTML {
        transformEnvironment({ $0.progressViewStyle = style })
    }

    func gaugeStyle(_ style: GaugeStyleKind) -> some HTML {
        transformEnvironment({ $0.gaugeStyle = style })
    }

    func tabViewStyle(_ style: TabViewStyleKind) -> some HTML {
        transformEnvironment({ $0.tabViewStyle = style })
    }
}

extension ToggleStyleKind {
    var className: String? { self == .automatic ? nil : "swui-toggle-style-\(rawValue)" }
}

extension TextFieldStyleKind {
    var className: String? { self == .automatic ? nil : "swui-text-field-style-\(rawValue)" }
}

extension LabelStyleKind {
    var className: String? { self == .automatic ? nil : "swui-label-style-\(rawValue)" }
}

extension ListStyleKind {
    var className: String? { self == .automatic ? nil : "swui-list-style-\(rawValue)" }
}

extension FormStyleKind {
    var className: String? { self == .automatic ? nil : "swui-form-style-\(rawValue)" }
}

extension MenuStyleKind {
    var className: String? { self == .automatic ? nil : "swui-menu-style-\(rawValue)" }
}

extension ProgressViewStyleKind {
    var className: String? { self == .automatic ? nil : "swui-progress-style-\(rawValue)" }
}

extension GaugeStyleKind {
    var className: String? { self == .automatic ? nil : "swui-gauge-style-\(rawValue)" }
}

extension TabViewStyleKind {
    var className: String? { self == .automatic ? nil : "swui-tabview-style-\(rawValue)" }
}

func controlClassName(_ parts: String?...) -> String {
    parts.compactMap { part in
        guard let part, !part.isEmpty else {
            return nil
        }
        return part
    }
    .joined(separator: " ")
}

#if !hasFeature(Embedded)
extension FormStyleKind: Codable {}
#endif
#if !hasFeature(Embedded)
extension GaugeStyleKind: Codable {}
#endif
#if !hasFeature(Embedded)
extension LabelStyleKind: Codable {}
#endif
#if !hasFeature(Embedded)
extension ListStyleKind: Codable {}
#endif
#if !hasFeature(Embedded)
extension MenuStyleKind: Codable {}
#endif
#if !hasFeature(Embedded)
extension ProgressViewStyleKind: Codable {}
#endif
#if !hasFeature(Embedded)
extension TabViewStyleKind: Codable {}
#endif
#if !hasFeature(Embedded)
extension TextFieldStyleKind: Codable {}
#endif
#if !hasFeature(Embedded)
extension ToggleStyleKind: Codable {}
#endif
