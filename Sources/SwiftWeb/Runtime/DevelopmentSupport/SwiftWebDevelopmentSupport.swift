import HTTPTypes
import Logging
import SwiftHTML
import Vapor

public struct SwiftWebDevelopmentHooks: Sendable {
    public var startParentMonitor: @Sendable (Logger) -> Task<Void, Never>?
    public var installMiddlewares: @Sendable (inout Middlewares) -> Void
    public var registerRoutes: @Sendable (any RoutesBuilder) -> Void
    public var htmlHeaders: @Sendable () -> HTTPFields
    public var injectHTML: @Sendable (_ html: String, _ nonce: String?) -> String
    public var annotateClientRuntimeHTML: @Sendable (
        _ html: String,
        _ manifest: ClientBundleManifest,
        _ hydrationIndex: BrowserHydrationIndex
    ) -> String

    public init(
        startParentMonitor: @escaping @Sendable (Logger) -> Task<Void, Never>?,
        installMiddlewares: @escaping @Sendable (inout Middlewares) -> Void,
        registerRoutes: @escaping @Sendable (any RoutesBuilder) -> Void,
        htmlHeaders: @escaping @Sendable () -> HTTPFields,
        injectHTML: @escaping @Sendable (_ html: String, _ nonce: String?) -> String,
        annotateClientRuntimeHTML: @escaping @Sendable (
            _ html: String,
            _ manifest: ClientBundleManifest,
            _ hydrationIndex: BrowserHydrationIndex
        ) -> String
    ) {
        self.startParentMonitor = startParentMonitor
        self.installMiddlewares = installMiddlewares
        self.registerRoutes = registerRoutes
        self.htmlHeaders = htmlHeaders
        self.injectHTML = injectHTML
        self.annotateClientRuntimeHTML = annotateClientRuntimeHTML
    }

    public static let disabled = SwiftWebDevelopmentHooks(
        startParentMonitor: { _ in nil },
        installMiddlewares: { _ in },
        registerRoutes: { _ in },
        htmlHeaders: { [.contentType: "text/html; charset=utf-8"] },
        injectHTML: { html, _ in html },
        annotateClientRuntimeHTML: { html, _, _ in html }
    )
}

public actor SwiftWebDevelopmentSupport {
    public static let shared = SwiftWebDevelopmentSupport()

    private var hooks: SwiftWebDevelopmentHooks = .disabled

    public func install(_ hooks: SwiftWebDevelopmentHooks) {
        self.hooks = hooks
    }

    public func reset() {
        hooks = .disabled
    }

    public func currentHooks() -> SwiftWebDevelopmentHooks {
        hooks
    }
}
