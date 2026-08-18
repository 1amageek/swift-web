#if hasFeature(Embedded) && !canImport(FoundationEssentials) && !canImport(Foundation)
/// The URL value used by SwiftWebUI when Foundation is unavailable.
///
/// SwiftWebUI only needs an immutable serialized URL at its HTML boundary.
/// Keeping that capability in this value avoids making the complete component
/// module depend on Foundation while preserving the `URL(string:)` authoring
/// surface across Standard and Embedded profiles.
public struct URL: Hashable, Sendable, CustomStringConvertible {
    public let absoluteString: String

    public init?(string: String) {
        guard !string.isEmpty,
              !string.utf8.contains(where: { $0 < 0x20 || $0 == 0x7F })
        else {
            return nil
        }
        self.absoluteString = string
    }

    public var description: String {
        absoluteString
    }
}
#endif
