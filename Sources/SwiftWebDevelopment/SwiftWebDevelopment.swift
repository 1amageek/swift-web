import SwiftWeb
import Vapor

public enum SwiftWebDevelopment {
    public static func install() async {
        await SwiftWebDevelopmentSupport.shared.install(.swiftWebDevelopment)
    }
}

extension SwiftWebDevelopmentHooks {
    static var swiftWebDevelopment: SwiftWebDevelopmentHooks {
        SwiftWebDevelopmentHooks(
            startParentMonitor: { logger in
                SwiftWebDevParentProcessMonitor.startIfNeeded(logger: logger)
            },
            installMiddlewares: { middlewares in
                if SwiftWebDevHotReload.isEnabled {
                    middlewares.use(SwiftWebDevRouteLoggingMiddleware(logLevel: .info))
                }
            },
            registerRoutes: { routes in
                _ = SwiftWebDevHotReload.register(on: routes)
            },
            htmlHeaders: {
                SwiftWebDevHotReload.headers()
            },
            injectHTML: { html, nonce in
                SwiftWebDevHotReload.inject(into: html, nonce: nonce)
            },
            annotateClientRuntimeHTML: { html, manifest, hydrationIndex in
                SwiftWebDevBoundaryAnnotator.annotate(
                    html,
                    manifest: manifest,
                    hydrationIndex: hydrationIndex
                )
            }
        )
    }
}
