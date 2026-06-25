import SwiftHTML

public enum ToggleStyleKind: String, Codable, Sendable, Equatable {
    case automatic
    case `switch`
    case checkbox
    case button
}

public enum TextFieldStyleKind: String, Codable, Sendable, Equatable {
    case automatic
    case plain
    case roundedBorder
    case squareBorder
}

public enum LabelStyleKind: String, Codable, Sendable, Equatable {
    case automatic
    case titleAndIcon
    case titleOnly
    case iconOnly
}

public enum ListStyleKind: String, Codable, Sendable, Equatable {
    case automatic
    case plain
    case inset
    case grouped
    case insetGrouped
    case sidebar
}

public enum FormStyleKind: String, Codable, Sendable, Equatable {
    case automatic
    case grouped
    case columns
}

public enum MenuStyleKind: String, Codable, Sendable, Equatable {
    case automatic
    case button
    case borderlessButton
}

public enum ProgressViewStyleKind: String, Codable, Sendable, Equatable {
    case automatic
    case linear
    case circular
}

public enum GaugeStyleKind: String, Codable, Sendable, Equatable {
    case automatic
    case linearCapacity
    case accessoryCircular
    case accessoryLinear
}

public enum TabViewStyleKind: String, Codable, Sendable, Equatable {
    case automatic
    case tabBar
    case page
}

public extension HTML {
    func toggleStyle(_ style: ToggleStyleKind) -> some HTML {
        environment(\.toggleStyle, style)
    }

    func textFieldStyle(_ style: TextFieldStyleKind) -> some HTML {
        environment(\.textFieldStyle, style)
    }

    func labelStyle(_ style: LabelStyleKind) -> some HTML {
        environment(\.labelStyle, style)
    }

    func listStyle(_ style: ListStyleKind) -> some HTML {
        environment(\.listStyle, style)
    }

    func formStyle(_ style: FormStyleKind) -> some HTML {
        environment(\.formStyle, style)
    }

    func menuStyle(_ style: MenuStyleKind) -> some HTML {
        environment(\.menuStyle, style)
    }

    func progressViewStyle(
        _ style: ProgressViewStyleKind
    ) -> some HTML {
        environment(\.progressViewStyle, style)
    }

    func gaugeStyle(_ style: GaugeStyleKind) -> some HTML {
        environment(\.gaugeStyle, style)
    }

    func tabViewStyle(_ style: TabViewStyleKind) -> some HTML {
        environment(\.tabViewStyle, style)
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
