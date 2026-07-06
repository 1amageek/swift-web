/// Exposes the page's decoded `SearchParams` to the page body:
///
///     @Page("/search")
///     struct SearchPage {
///         struct SearchParams: Decodable, Sendable {
///             let q: String
///         }
///
///         @Query var query: SearchParams
///
///         func body() -> some HTML { ... }
///     }
///
/// The value is decoded once per request by the route registration the
/// `@Page` macro generates; the wrapper reads it from `RequestContext`.
@propertyWrapper
public struct Query<Value>: Sendable {
    public init() {}

    public var wrappedValue: Value {
        ServerCapabilityReadContext.record("@Query", valueType: Value.self)
        guard let context = RequestContext.current else {
            preconditionFailure("@Query was accessed outside a SwiftWeb page request")
        }
        return context.searchParams(as: Value.self)
    }
}
