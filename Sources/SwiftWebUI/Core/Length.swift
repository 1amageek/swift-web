public enum Length: Sendable, Equatable, ExpressibleByIntegerLiteral, ExpressibleByFloatLiteral {
    public enum Unit: String, Sendable, Equatable {
        case px
        case em
        case rem
        case percent = "%"
        case vw
        case vh
        case vmin
        case vmax
        case svw
        case svh
        case lvw
        case lvh
        case dvw
        case dvh
        case ch
        case ex
        case fr
        case cm
        case mm
        case q
        case inch = "in"
        case pc
        case pt
    }

    case value(Double, Unit)
    case custom(String)
    case infinity

    public init(integerLiteral value: Int) {
        self = .px(Double(value))
    }

    public init(floatLiteral value: Double) {
        self = .px(value)
    }

    public init(_ value: Double, unit: Unit = .px) {
        self = .value(value, unit)
    }

    public static func px(_ value: Double) -> Self {
        .value(value, .px)
    }

    public static func em(_ value: Double) -> Self {
        .value(value, .em)
    }

    public static func rem(_ value: Double) -> Self {
        .value(value, .rem)
    }

    public static func percent(_ value: Double) -> Self {
        .value(value, .percent)
    }

    public static func vw(_ value: Double) -> Self {
        .value(value, .vw)
    }

    public static func vh(_ value: Double) -> Self {
        .value(value, .vh)
    }

    public static func ch(_ value: Double) -> Self {
        .value(value, .ch)
    }

    public static func fr(_ value: Double) -> Self {
        .value(value, .fr)
    }

    var cssValue: String {
        switch self {
        case .value(let value, let unit):
            "\(trimmedNumber(value))\(unit.rawValue)"
        case .custom(let value):
            value
        case .infinity:
            "100%"
        }
    }
}
