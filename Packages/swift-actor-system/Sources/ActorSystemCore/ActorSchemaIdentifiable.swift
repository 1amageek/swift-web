public protocol ActorSchemaIdentifiable: Sendable {
    static var actorTypeDescriptor: ActorTypeDescriptor { get }
}

public protocol ActorSystemReference: ActorSchemaIdentifiable {
    associatedtype ActorSystem: Sendable

    var id: ActorAddress { get }
    var actorSystem: ActorSystem { get }

    static func resolve(
        id: ActorAddress,
        using actorSystem: ActorSystem
    ) throws -> Self
}

public protocol ActorSchemaModule: Sendable {
    static var actorTypeDescriptors: [ActorTypeDescriptor] { get }
}
