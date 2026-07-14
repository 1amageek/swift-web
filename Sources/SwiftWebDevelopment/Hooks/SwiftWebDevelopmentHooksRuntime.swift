import Foundation
import SwiftWebCore

public enum SwiftWebDevelopmentHooksRuntime {
    public static func install() async {
        await SwiftWebDevelopmentSupport.shared.install(.swiftWebDevelopment)
    }
}

extension SwiftWebDevelopmentHooks {
    package static var swiftWebDevelopment: SwiftWebDevelopmentHooks {
        SwiftWebDevelopmentHooks(
            startParentMonitor: { logger in
                SwiftWebDevParentProcessMonitor.startIfNeeded(logger: logger)
            },
            configureSecurity: { configuration in
                guard SwiftWebDevHotReload.isEnabled else {
                    return configuration
                }
                var configuration = configuration
                configuration.forwardedHeaders = .trust
                return configuration
            },
            installMiddlewares: { middlewares in
                if SwiftWebDevHotReload.isEnabled {
                    middlewares.use(SwiftWebDevContextMiddleware())
                    if let fingerprintMiddleware = SwiftWebDevBuildFingerprintMiddleware(
                        environment: ProcessInfo.processInfo.environment
                    ) {
                        middlewares.use(fingerprintMiddleware)
                    }
                    if SwiftWebDevRouteLoggingMiddleware.isEnabled {
                        middlewares.use(SwiftWebDevRouteLoggingMiddleware(logLevel: .info))
                    }
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
                if let store = SwiftWebDevClientManifestSnapshotStore() {
                    store.record(manifest)
                }
                return SwiftWebDevBoundaryAnnotator.annotate(
                    html,
                    manifest: manifest,
                    hydrationIndex: hydrationIndex
                )
            }
        )
    }
}
