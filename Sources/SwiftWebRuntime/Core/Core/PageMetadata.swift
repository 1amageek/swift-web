public struct PageMetadata: Sendable, Equatable {
    public let title: String
    public let description: String?
    public let language: String
    /// A class applied to the document `<body>`, letting a page opt into a
    /// body-level surface (e.g. a full-viewport app shell) styled by the SwiftWebUI root.
    public let bodyClass: String?

    public init(
        title: String,
        description: String? = nil,
        language: String = "en",
        bodyClass: String? = nil
    ) {
        self.title = title
        self.description = description
        self.language = language
        self.bodyClass = bodyClass
    }
}
