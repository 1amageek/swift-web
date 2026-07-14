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
extension ControlState: Codable {}
#endif
