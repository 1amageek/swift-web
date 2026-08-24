import ActorSystemCore
#if hasFeature(Embedded)
import ActorSystemEmbedded
#endif
import SwiftWebActors

enum ClientRuntimeActorSystemFactory {
    struct Installation {
        let actorSystem: WebActorSystem
        let routeBindingRouter: SwiftWebActorBindingRouter?
    }

    static func makeActorSystem() -> Installation {
        #if os(WASI) && SWIFTWEB_ACTORS
        let configuration = ActorSystemConfiguration(
            sessionIdentitySource: JavaScriptKitActorSessionIdentitySource()
        )
        do {
            let routeBindingRouter = SwiftWebActorBindingRouter(
                fallback: SwiftWebHTTPActorRouter()
            )
            let requestTransport = JavaScriptKitActorTransport(
                configuration: configuration
            )
            let actorSystem = try WebActorSystem(
                router: routeBindingRouter,
                transports: [.swiftWebHTTP: requestTransport],
                configuration: configuration
            )
            return Installation(
                actorSystem: actorSystem,
                routeBindingRouter: routeBindingRouter
            )
        } catch {
            preconditionFailure(
                "The default browser actor transport configuration is invalid: \(error)"
            )
        }
        #elseif os(WASI) && hasFeature(Embedded)
        let configuration = ActorSystemConfiguration(
            sessionIdentitySource: JavaScriptKitActorSessionIdentitySource()
        )
        do {
            let routeBindingRouter = SwiftWebActorBindingRouter(
                fallback: SwiftWebHTTPActorRouter()
            )
            let requestTransport = JavaScriptKitActorTransport(
                configuration: configuration
            )
            let actorSystem = WebActorSystem(
                router: routeBindingRouter,
                transports: [.swiftWebHTTP: requestTransport],
                configuration: configuration
            )
            return Installation(
                actorSystem: actorSystem,
                routeBindingRouter: routeBindingRouter
            )
        } catch {
            _ = error
            preconditionFailure(
                "The default Embedded browser actor transport configuration is invalid"
            )
        }
        #else
        return Installation(
            actorSystem: WebActorSystem.shared,
            routeBindingRouter: nil
        )
        #endif
    }

    #if SWIFTWEB_LEGACY_ACTORS
    static func makeLegacyActorSystem() -> LegacyWebActorSystem {
        #if os(WASI) && !hasFeature(Embedded)
        return LegacyWebActorSystem(transport: JavaScriptKitWebActorTransport())
        #else
        return LegacyWebActorSystem.shared
        #endif
    }
    #endif
}
