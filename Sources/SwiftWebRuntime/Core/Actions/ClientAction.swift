#if !hasFeature(Embedded)
// Server actions are a Codable JSON API boundary; the embedded SSR
// profile does not serve them.
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
            .data("client-action", name)
            .data("trigger", trigger.rawValue)
            .data("action-url", action)
        if let target {
            element = element.data("target", target)
        }
        return element
    }
}
#endif
