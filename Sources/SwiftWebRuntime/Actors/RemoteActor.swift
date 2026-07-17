#if SWIFTWEB_ACTORS
#if SWIFTWEB_MACROS
/// Injects the resolved distributed actor service for the declared contract type.
///
/// The macro expands the property into an accessor that resolves the service
/// from the active `SwiftWebActorBindingContext` scope. It is a macro, not a
/// type, so the browser package materializer can expand it textually.
///
/// Generated browser WASM packages compile without SwiftWebMacros: the package
/// materializer expands `@RemoteActor` properties in copied client sources, and this
/// declaration is compiled out because SWIFTWEB_MACROS is not defined there.
@attached(accessor)
public macro RemoteActor() = #externalMacro(module: "SwiftWebMacros", type: "RemoteActorMacro")
#endif
#endif
