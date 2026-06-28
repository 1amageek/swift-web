import SwiftWebUITheme

public struct CGSize: Sendable, Equatable {
    public var width: Length
    public var height: Length

    public init(width: Length, height: Length) {
        self.width = width
        self.height = height
    }
}

public struct CGPoint: Sendable, Equatable {
    public var x: Length
    public var y: Length

    public init(x: Length, y: Length) {
        self.x = x
        self.y = y
    }
}
