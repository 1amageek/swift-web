#if SWIFTWEB_ACTORS
#if SWIFTWEB_MACROS
/// Injects the resolved distributed actor service for the declared contract type.
///
/// The macro expands the property into an accessor that resolves the service
/// from the active `SwiftWebActorBindingContext` scope. It is a macro, not a
/// type, so it never shadows the standard library `Swift.Actor` protocol.
///
/// Generated browser WASM packages compile without SwiftWebMacros: the package
/// materializer expands `@Actor` properties in copied client sources, and this
/// declaration is compiled out because SWIFTWEB_MACROS is not defined there.
@attached(accessor)
public macro Actor() = #externalMacro(module: "SwiftWebMacros", type: "ActorMacro")
#endif
#endif
