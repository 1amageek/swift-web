public enum ClientActionTrigger: String, Sendable {
    case click
    case input
    case submit
}

public protocol ClientAction: SendableMetatype {
    associatedtype Input: Encodable & Sendable
    associatedtype Output: Decodable & Sendable

    static var name: String { get }
}

public extension ElementRepresentable {
    func clientAction(
        _ name: String,
        trigger: ClientActionTrigger,
        action: String,
        target: String? = nil
    ) -> Self {
        var element = self
            .data("swift-web-client-action", name)
            .data("swift-web-trigger", trigger.rawValue)
            .data("swift-web-action-url", action)
        if let target {
            element = element.data("swift-web-target", target)
        }
        return element
    }
}
