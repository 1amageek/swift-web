/// A host-neutral uploaded file decoded from a request body.
public struct File: Sendable {
    public let data: [UInt8]
    public let filename: String
    public let contentType: String?

    public init(data: [UInt8], filename: String, contentType: String? = nil) {
        self.data = data
        self.filename = filename
        self.contentType = contentType
    }
}

#if !hasFeature(Embedded)
extension File: Decodable {}
#endif
