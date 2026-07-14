/// The parsed query string of a request URL. Semantics are defined by the
/// framework (see `FormParsing`) and identical on every host, so a page
/// reads the same values no matter which runtime serves it.
public struct QueryParameters: Sendable, RequestParameters {
    private let fields: [String: [String]]

    public init(rawQuery: String?) {
        if let rawQuery, !rawQuery.isEmpty {
            self.fields = FormParsing.parse(rawQuery)
        } else {
            self.fields = [:]
        }
    }

    public func rawValue(_ name: String) -> String? {
        fields[name]?.first
    }

    public func rawValues(_ name: String) -> [String] {
        fields[name] ?? []
    }

    public var isEmpty: Bool {
        fields.isEmpty
    }
}
