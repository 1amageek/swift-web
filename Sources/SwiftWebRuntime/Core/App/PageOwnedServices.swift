
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
    }

    public static func register<Handler>(
        _ handler: Handler,
        on application: Application
    ) async throws where Handler: Sendable {
        for descriptor in ServerActionDescriptorReader.descriptors(in: handler) {
            try application.swiftWebServerActions.register(handler: handler, descriptor: descriptor)
        }
    }

    public static func register(_ value: Any, on application: Application) async throws {
        if let actions = value as? any PageOwnedServerActions {
            try await actions.registerServerActions(on: application)
        }
        if let services = value as? any AppServices {
            try await services.register(on: application)
        }
    }

    public static func register(
        _ value: Any,
        on application: Application,
        routes: any RoutesBuilder,
        basePath: RoutePath = RoutePath("/")
    ) async throws {
        if let actions = value as? any PageOwnedServerActions {
            try await actions.registerServerActions(on: application, routes: routes, basePath: basePath)
        }
        if let services = value as? any AppServices {
            try await services.register(on: application)
        }
    }
}

private enum ServerActionDescriptorReader {
    static func descriptors(in value: Any) -> [ServerActionDescriptor] {
        Mirror(reflecting: value).children.compactMap { child in
            child.value as? ServerActionDescriptor
        }
    }
}
