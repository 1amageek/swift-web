public enum FontWeight: String, Sendable, Equatable {
    case ultraLight = "200"
    case thin = "300"
    case light = "350"
    case regular = "400"
    case medium = "500"
    case semibold = "600"
    case bold = "700"
    case heavy = "800"
    case black = "900"

    var cssValue: String {
        rawValue
    }
}
