import SwiftWebUITheme
public enum ControlSize: String, Sendable, Codable, Equatable {
    case mini
    case small
    case regular
    case large
    case extraLarge

    var className: String {
        "swui-control-\(rawValue)"
    }
}
