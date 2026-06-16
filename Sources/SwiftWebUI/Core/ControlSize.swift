public enum ControlSize: String, Sendable, Codable, Equatable {
    case mini
    case small
    case regular
    case large

    var className: String {
        "swui-control-\(rawValue)"
    }
}
