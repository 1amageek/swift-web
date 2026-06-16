public struct PageMetadata: Sendable, Equatable {
    public let title: String
    public let description: String?
    public let language: String

    public init(
        title: String,
        description: String? = nil,
        language: String = "en"
    ) {
        self.title = title
        self.description = description
        self.language = language
    }
}
