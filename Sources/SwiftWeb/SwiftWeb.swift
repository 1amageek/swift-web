@_exported import SwiftWebActors
@_exported import SwiftWebBrowserRuntime
@_exported import SwiftWebCore

@attached(member, names: named(params), named(searchParams), named(_bindParams), named(_bindSearchParams), named(url))
@attached(extension, conformances: PageRoute, Page, names: named(register), named(registerPageOwnedServices))
public macro Page(_ path: String) = #externalMacro(module: "SwiftWebMacros", type: "PageMacro")

#if !hasFeature(Embedded)
// Server actions are a Codable JSON API boundary; the embedded SSR profile
// does not serve them (see SwiftWebCore/Actions).
@attached(peer, names: arbitrary)
public macro ServerAction(_ path: String) = #externalMacro(module: "SwiftWebMacros", type: "ServerActionMacro")

@attached(peer, names: arbitrary)
public macro ServerAction(_ method: ServerActionMethod, _ path: String) = #externalMacro(module: "SwiftWebMacros", type: "ServerActionMacro")
#endif

#if SWIFTWEB_ACTORS
@attached(extension, conformances: SwiftWebActorExporting, names: named(SwiftWebActorContract), named(swiftWebActorContractKey), named(_swiftWebActorContractTypeCheck))
public macro ResolvableActor(_ contract: Any.Type) = #externalMacro(module: "SwiftWebMacros", type: "ResolvableActorMacro")
#endif
