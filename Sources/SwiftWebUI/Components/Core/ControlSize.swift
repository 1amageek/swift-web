import SwiftWebUITheme
public enum ControlSize: String, Sendable, Equatable {
    case mini
    case small
    case regular
    case large
    case extraLarge

    var className: String {
        "swui-control-\(rawValue)"
    }
}

#if !hasFeature(Embedded)
extension ControlSize: Codable {}
#endif
