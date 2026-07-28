public struct ControlState: Sendable, Equatable {
    public var isEnabled: Bool
    public var isPressed: Bool
    public var isFocused: Bool
    public var isSelected: Bool

    public init(
        isEnabled: Bool = true,
        isPressed: Bool = false,
        isFocused: Bool = false,
        isSelected: Bool = false
    ) {
        self.isEnabled = isEnabled
        self.isPressed = isPressed
        self.isFocused = isFocused
        self.isSelected = isSelected
    }

    public static let enabled = ControlState()
    public static let disabled = ControlState(isEnabled: false)
}

#if !hasFeature(Embedded)
extension ControlState: Codable {
    public init(from decoder: any Decoder) throws {
        var container = try decoder.unkeyedContainer()
        self.init(
            isEnabled: try container.decode(Bool.self),
            isPressed: try container.decode(Bool.self),
            isFocused: try container.decode(Bool.self),
            isSelected: try container.decode(Bool.self)
        )
    }

    public func encode(to encoder: any Encoder) throws {
        var container = encoder.unkeyedContainer()
        try container.encode(isEnabled)
        try container.encode(isPressed)
        try container.encode(isFocused)
        try container.encode(isSelected)
    }
}
#endif
