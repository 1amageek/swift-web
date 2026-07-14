
public protocol PageOwnedServerActions: Sendable {
    func registerServerActions(
        on application: Application,
        routes: any RoutesBuilder,
        basePath: RoutePath
    ) async throws

    func registerServerActions(on application: Application) async throws
}

public extension PageOwnedServerActions {
    func registerServerActions(
        on application: Application,
        routes: any RoutesBuilder,
        basePath: RoutePath
    ) async throws {
        try await PageOwnedServices.register(self, on: application, routes: routes, basePath: basePath)
    }

    func registerServerActions(on application: Application) async throws {
        try await PageOwnedServices.register(self, on: application)
    }
}

public enum PageOwnedServices {
    public static func register<Handler>(
        _ handler: Handler,
        on application: Application,
        routes: any RoutesBuilder,
        basePath: RoutePath = RoutePath("/")
    ) async throws where Handler: Sendable {
        #if !hasFeature(Embedded)
        for descriptor in ServerActionDescriptorReader.descriptors(in: handler) {
            let routePath = ServerActionPath.routePath(for: descriptor.path, basePath: basePath)
            try ActionGateway.register(
                handler: handler,
                descriptor: descriptor,
                path: routePath,
                on: routes,
                application: application
            )
        }
        #endif
        // Embedded: @ServerAction descriptors reference gated Codable types,
        // so a handler carrying them cannot compile on this profile at all —
        // there is nothing to scan.
    }

    public static func register<Handler>(
        _ handler: Handler,
        on application: Application
    ) async throws where Handler: Sendable {
        #if !hasFeature(Embedded)
        for descriptor in ServerActionDescriptorReader.descriptors(in: handler) {
            try application.swiftWebServerActions.register(handler: handler, descriptor: descriptor)
        }
        #endif
    }

    // MARK: Stored-property service registration
    //
    // Overload dispatch replaces the former `Any` + runtime-cast design: the
    // @Page macro passes each stored property with its concrete type, so the
    // compiler statically selects the capability overloads below. This is
    // both checked at compile time and free of existential casts (which
    // Embedded Swift does not support for non-class protocols).

    public static func registerService(
        _ value: some Sendable,
        on application: Application,
        routes: any RoutesBuilder,
        basePath: RoutePath = RoutePath("/")
    ) async throws {
        // Plain page state: nothing to register.
    }

    public static func registerService(
        _ value: some AppServices,
        on application: Application,
        routes: any RoutesBuilder,
        basePath: RoutePath = RoutePath("/")
    ) async throws {
        try await value.register(on: application)
    }

    public static func registerService(_ value: some Sendable, on application: Application) async throws {}

    public static func registerService(_ value: some AppServices, on application: Application) async throws {
        try await value.register(on: application)
    }

    #if !hasFeature(Embedded)
    public static func registerService(
        _ value: some PageOwnedServerActions,
        on application: Application,
        routes: any RoutesBuilder,
        basePath: RoutePath = RoutePath("/")
    ) async throws {
        try await value.registerServerActions(on: application, routes: routes, basePath: basePath)
    }

    public static func registerService(
        _ value: some AppServices & PageOwnedServerActions,
        on application: Application,
        routes: any RoutesBuilder,
        basePath: RoutePath = RoutePath("/")
    ) async throws {
        try await value.registerServerActions(on: application, routes: routes, basePath: basePath)
        try await value.register(on: application)
    }

    public static func registerService(_ value: some PageOwnedServerActions, on application: Application) async throws {
        try await value.registerServerActions(on: application)
    }

    public static func registerService(_ value: some AppServices & PageOwnedServerActions, on application: Application) async throws {
        try await value.registerServerActions(on: application)
        try await value.register(on: application)
    }
    #endif
}

#if !hasFeature(Embedded)
private enum ServerActionDescriptorReader {
    static func descriptors(in value: Any) -> [ServerActionDescriptor] {
        Mirror(reflecting: value).children.compactMap { child in
            child.value as? ServerActionDescriptor
        }
    }
}
#endif
