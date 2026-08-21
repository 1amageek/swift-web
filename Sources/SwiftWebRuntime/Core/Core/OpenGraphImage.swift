/// An image that represents a page when it is shared through Open Graph.
public struct OpenGraphImage: Sendable, Equatable {
    public let url: String
    public let secureURL: String?
    public let mediaType: String?
    public let width: Int?
    public let height: Int?
    public let alt: String

    public init(
        url: String,
        secureURL: String? = nil,
        mediaType: String? = nil,
        width: Int? = nil,
        height: Int? = nil,
        alt: String
    ) {
        self.url = url
        self.secureURL = secureURL
        self.mediaType = mediaType
        self.width = width
        self.height = height
        self.alt = alt
    }
}
