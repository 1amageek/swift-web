public struct ClientSecurityDescriptor: Sendable, Equatable {
    public let csrfToken: String?
    public let csrfHeaderName: String
    public let csrfFieldName: String

    public init(
        csrfToken: String?,
        csrfHeaderName: String,
        csrfFieldName: String
    ) {
        self.csrfToken = csrfToken
        self.csrfHeaderName = csrfHeaderName
        self.csrfFieldName = csrfFieldName
    }
}

#if !hasFeature(Embedded)
extension ClientSecurityDescriptor: Codable {}
#endif
