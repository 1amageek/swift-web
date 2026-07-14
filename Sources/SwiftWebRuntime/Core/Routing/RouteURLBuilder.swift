import SwiftWebHost
import SwiftHTML
#if canImport(FoundationEssentials)
import FoundationEssentials
#elseif canImport(Foundation)
import Foundation
#endif

/// The URL type page-route builders produce: Foundation's `URL` on full
/// profiles, the SwiftHTML stand-in on Embedded.
public typealias RouteURL = URL

/// Assembles the URL for a page route from typed parameter values. The
/// `@Page` macro generates `url(...)` builders on top of this; encoding is
/// shared with the request-side parser, so a generated link always parses
/// back to the values it was built from.
public struct RouteURLBuilder: Sendable {
    private var path = ""
    private var query = ""

    public init() {}

    public mutating func appendPathSegment(_ segment: String) {
        path += "/"
        path += PercentCoding.encodePathSegment(segment)
    }

    public mutating func appendPathSegment<Value: LosslessStringConvertible>(_ value: Value) {
        appendPathSegment(value.description)
    }

    public mutating func appendPathSegment<Value: RawRepresentable>(
        _ value: Value
    ) where Value.RawValue: LosslessStringConvertible {
        appendPathSegment(value.rawValue.description)
    }

    public mutating func appendQuery(_ name: String, _ value: String) {
        if !query.isEmpty {
            query += "&"
        }
        query += PercentCoding.encodeQueryComponent(name)
        query += "="
        query += PercentCoding.encodeQueryComponent(value)
    }

    /// The wire form of a parameter value; also used to compare a value
    /// against its declared default when deciding whether to omit it.
    public static func wire<Value: LosslessStringConvertible>(_ value: Value) -> String {
        value.description
    }

    public static func wire<Value: RawRepresentable>(
        _ value: Value
    ) -> String where Value.RawValue: LosslessStringConvertible {
        value.rawValue.description
    }

    public var url: RouteURL {
        let rendered = (path.isEmpty ? "/" : path) + (query.isEmpty ? "" : "?" + query)
        guard let url = RouteURL(string: rendered) else {
            fatalError("RouteURLBuilder produced an unparseable URL: \(rendered)")
        }
        return url
    }
}

extension ParameterError {
    /// The response a route returns when a request fails parameter binding.
    public func badRequestResponse() -> Response {
        Response(
            status: .badRequest,
            headers: [.contentType: "text/plain; charset=utf-8"],
            body: .init(string: "Bad Request: \(message)")
        )
    }
}
