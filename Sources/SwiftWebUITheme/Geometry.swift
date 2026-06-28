public struct EdgeInsets: Sendable, Equatable {
    public var top: Length
    public var leading: Length
    public var bottom: Length
    public var trailing: Length

    public init(
        top: Length,
        leading: Length,
        bottom: Length,
        trailing: Length
    ) {
        self.top = top
        self.leading = leading
        self.bottom = bottom
        self.trailing = trailing
    }

    public init(_ length: Length) {
        self.init(top: length, leading: length, bottom: length, trailing: length)
    }

    package var cssValue: String {
        "\(top.cssValue) \(trailing.cssValue) \(bottom.cssValue) \(leading.cssValue)"
    }
}

public enum VerticalEdge: Sendable {
    case top
    case bottom

    public struct Set: OptionSet, Sendable {
        public let rawValue: Int

        public init(rawValue: Int) {
            self.rawValue = rawValue
        }

        public static let top = Set(rawValue: 1 << 0)
        public static let bottom = Set(rawValue: 1 << 1)
        public static let all: Set = [.top, .bottom]
    }
}

public enum HorizontalEdge: Sendable {
    case leading
    case trailing

    public struct Set: OptionSet, Sendable {
        public let rawValue: Int

        public init(rawValue: Int) {
            self.rawValue = rawValue
        }

        public static let leading = Set(rawValue: 1 << 0)
        public static let trailing = Set(rawValue: 1 << 1)
        public static let all: Set = [.leading, .trailing]
    }
}

public struct UnitPoint: Sendable, Equatable {
    public var x: Double
    public var y: Double

    public init(x: Double, y: Double) {
        self.x = x
        self.y = y
    }

    public static let zero = UnitPoint(x: 0, y: 0)
    public static let center = UnitPoint(x: 0.5, y: 0.5)
    public static let leading = UnitPoint(x: 0, y: 0.5)
    public static let trailing = UnitPoint(x: 1, y: 0.5)
    public static let top = UnitPoint(x: 0.5, y: 0)
    public static let bottom = UnitPoint(x: 0.5, y: 1)
    public static let topLeading = UnitPoint(x: 0, y: 0)
    public static let topTrailing = UnitPoint(x: 1, y: 0)
    public static let bottomLeading = UnitPoint(x: 0, y: 1)
    public static let bottomTrailing = UnitPoint(x: 1, y: 1)

    package var cssValue: String {
        "\(trimmedNumber(x * 100))% \(trimmedNumber(y * 100))%"
    }
}

public struct Angle: Sendable, Equatable {
    public var degrees: Double

    public init(degrees: Double) {
        self.degrees = degrees
    }

    public init(radians: Double) {
        self.degrees = radians * 180 / .pi
    }

    public static func degrees(_ degrees: Double) -> Angle {
        Angle(degrees: degrees)
    }

    public static func radians(_ radians: Double) -> Angle {
        Angle(radians: radians)
    }

    package var cssValue: String {
        "\(trimmedNumber(degrees))deg"
    }
}
