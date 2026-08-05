/// Marks a page-owned value whose `@ServerAction` methods are registered with
/// the page that stores it.
public protocol PageOwnedServerActions: Sendable {}

/// Framework rendering state used by macro-generated page action wiring.
public struct PageActionRegistrationContext: Sendable {
    package let runtime: AppRuntime
    package let routes: any RoutesBuilder

    package init(runtime: AppRuntime, routes: any RoutesBuilder) {
        self.runtime = runtime
        self.routes = routes
    }
}

/// Registers `@ServerAction` descriptors discovered on a page or on one of
/// its explicitly marked stored values.
public enum PageOwnedActions {
    public static func register<Handler>(
        _ handler: Handler,
        in context: PageActionRegistrationContext,
        basePath: RoutePath = RoutePath("/")
    ) async throws where Handler: Sendable {
        #if !hasFeature(Embedded)
        for descriptor in ServerActionDescriptorReader.descriptors(in: handler) {
            let routePath = ServerActionPath.routePath(
                for: descriptor.path,
                basePath: basePath
            )
            try PageActionRouteRegistration.register(
                handler: handler,
                descriptor: descriptor,
                path: routePath,
                on: context.routes,
                runtime: context.runtime
            )
        }
        #endif
    }

    public static func registerActions(
        from value: some Sendable,
        in context: PageActionRegistrationContext,
        basePath: RoutePath = RoutePath("/")
    ) async throws {}

    public static func registerActions(
        from value: some PageOwnedServerActions,
        in context: PageActionRegistrationContext,
        basePath: RoutePath = RoutePath("/")
    ) async throws {
        try await register(value, in: context, basePath: basePath)
    }
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
