/// Page-level Open Graph values that complement ``PageMetadata``.
///
/// The document title and description remain the canonical values in
/// ``PageMetadata`` and are reused for `og:title` and `og:description`.
public struct OpenGraphMetadata: Sendable, Equatable {
    public let type: String
    public let url: String
    public let siteName: String?
    public let locale: String?
    public let alternateLocales: [String]
    public let image: OpenGraphImage

    public init(
        type: String,
        url: String,
        siteName: String? = nil,
        locale: String? = nil,
        alternateLocales: [String] = [],
        image: OpenGraphImage
    ) {
        self.type = type
        self.url = url
        self.siteName = siteName
        self.locale = locale
        self.alternateLocales = alternateLocales
        self.image = image
    }
}
