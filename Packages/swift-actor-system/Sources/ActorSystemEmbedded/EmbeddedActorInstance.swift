import ActorSystemCore

/// A generated actor instance that can be retained and resolved by an
/// `EmbeddedActorSystem` without relying on runtime dynamic casting.
public protocol EmbeddedActorInstance: ActorSchemaIdentifiable, AnyObject {}
