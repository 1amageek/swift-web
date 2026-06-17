import Distributed
import SwiftWebActors
import Vapor

public enum PageOwnedServices {
    public static func register<Act>(
        _ actor: Act,
        on application: Application
    ) async throws where Act: DistributedActor & Sendable, Act.ID == WebActorSystem.ActorID, Act.ActorSystem == WebActorSystem {
        for descriptor in ServerActionDescriptorReader.descriptors(in: actor) {
            application.swiftWebServerActions.register(actor: actor, descriptor: descriptor)
        }
    }

    public static func register(_ value: Any, on application: Application) async throws {
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
