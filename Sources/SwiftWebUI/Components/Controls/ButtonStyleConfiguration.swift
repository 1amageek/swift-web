public struct ButtonStyleConfiguration: Sendable, Equatable {
    public let prominence: ButtonProminence
    public let controlSize: ControlSize
    public let isEnabled: Bool
    public let tint: String

    public init(
        prominence: ButtonProminence,
        controlSize: ControlSize,
        isEnabled: Bool,
        tint: String
    ) {
        self.prominence = prominence
        self.controlSize = controlSize
        self.isEnabled = isEnabled
        self.tint = tint
    }
}
