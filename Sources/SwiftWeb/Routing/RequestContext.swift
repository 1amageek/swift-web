import SwiftHTML

public struct RequestValues: Sendable {
    public let request: Request
    public let security: RequestSecurityContext?

    private let paramsValue: any Sendable
    private let searchParamsValue: any Sendable

    public init<Params: Sendable, SearchParams: Sendable>(
        request: Request,
        params: Params,
        searchParams: SearchParams,
        security: RequestSecurityContext? = nil
    ) {
        self.request = request
        self.security = security ?? request.securityContext
        self.paramsValue = params
        self.searchParamsValue = searchParams
    }

    public func params<Params>(as type: Params.Type = Params.self) -> Params {
        guard let params = self.paramsValue as? Params else {
            preconditionFailure("Request context does not contain params of type \(Params.self)")
        }
        return params
    }

    public func searchParams<SearchParams>(as type: SearchParams.Type = SearchParams.self) -> SearchParams {
        guard let searchParams = self.searchParamsValue as? SearchParams else {
            preconditionFailure("Request context does not contain search params of type \(SearchParams.self)")
        }
        return searchParams
    }

    public var routeEnvironment: RouteEnvironment {
        RouteEnvironment(
            method: request.method.rawValue,
            url: request.url.string,
            path: request.url.path,
            params: paramsValue,
            searchParams: searchParamsValue
        )
    }
}

public enum RequestContext {
    @TaskLocal public static var current: RequestValues?

    public static var request: Request {
        guard let request = current?.request else {
            preconditionFailure("RequestContext.request was accessed outside a SwiftWeb page request")
        }
        return request
    }

    public static func withValue<Result: Sendable>(
        _ value: RequestValues,
        operation: @Sendable () async throws -> Result
    ) async rethrows -> Result {
        try await EnlargedStackContext.withValue(RequestContextPropagator(value: value)) {
            try await $current.withValue(value, operation: operation)
        }
    }
}

private struct RequestContextPropagator: EnlargedStackContextPropagator {
    let value: RequestValues

    func apply<Result>(_ operation: () throws -> Result) rethrows -> Result {
        try RequestContext.$current.withValue(value, operation: operation)
    }
}

public struct ServerValues: Sendable {
    public let context: RequestValues

    public init(context: RequestValues) {
        self.context = context
    }

    public var request: Request {
        context.request
    }
}

public protocol ServerValueKey: Sendable {
    associatedtype Value

    static var serverCapabilityName: String { get }
    static func value(from values: ServerValues) -> Value
}

public extension ServerValueKey {
    static var serverCapabilityName: String {
        String(reflecting: Self.self)
    }
}

public struct RequestServerValueKey: ServerValueKey {
    public static let serverCapabilityName = "RequestServerValueKey.self"

    public static func value(from values: ServerValues) -> Request {
        values.request
    }

    public init() {}
}

@propertyWrapper
public struct Server<Value>: Sendable {
    private let capability: String
    private let read: @Sendable (ServerValues) -> Value

    public init<Key: ServerValueKey>(_ key: Key.Type) where Key.Value == Value {
        self.capability = "@Server(\(Key.serverCapabilityName))"
        self.read = { values in
            Key.value(from: values)
        }
    }

    public var wrappedValue: Value {
        ServerCapabilityReadContext.record(capability, valueType: Value.self)
        guard let context = RequestContext.current else {
            preconditionFailure("@Server was accessed outside a SwiftWeb page request")
        }
        return read(ServerValues(context: context))
    }
}
