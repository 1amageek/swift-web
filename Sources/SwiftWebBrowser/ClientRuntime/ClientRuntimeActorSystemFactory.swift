import ActorSystemCore
#if hasFeature(Embedded)
import ActorSystemEmbedded
#endif
import SwiftWebActors

enum ClientRuntimeActorSystemFactory {
    static func makeActorSystem() -> WebActorSystem {
        #if os(WASI) && SWIFTWEB_ACTORS
        let configuration = ActorSystemConfiguration(
            sessionIdentitySource: JavaScriptKitActorSessionIdentitySource()
        )
        do {
            let channel = try BrowserSwiftWebActorBinaryChannel(
                configuration: configuration
            )
            let transport = try SwiftWebWebSocketActorTransport(
                configuration: configuration,
                channels: [(channel, ActorByteBuffer())]
            )
            return try WebActorSystem(
                router: SwiftWebWebSocketActorRouter(),
                transports: [.swiftWebWebSocket: transport],
                configuration: configuration
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
            let channel = try BrowserSwiftWebActorBinaryChannel(
                configuration: configuration
            )
            let transport = try SwiftWebWebSocketActorTransport(
                configuration: configuration,
                channels: [(channel, ActorByteBuffer())]
            )
            return WebActorSystem(
                router: SwiftWebWebSocketActorRouter(),
                transports: [.swiftWebWebSocket: transport],
                configuration: configuration
            )
        } catch {
            _ = error
            preconditionFailure(
                "The default Embedded browser actor transport configuration is invalid"
            )
        }
        #else
        return WebActorSystem.shared
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
