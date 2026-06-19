struct ButtonStyleConfiguration: Sendable, Equatable {
    let prominence: ButtonProminence
    let controlSize: ControlSize
    let isEnabled: Bool
    let tint: String

    init(
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
