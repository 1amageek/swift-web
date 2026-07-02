@_exported import SwiftWebActors
@_exported import SwiftWebBrowserRuntime
@_exported import SwiftWebCore

@attached(member, names: named(params), named(searchParams))
@attached(extension, conformances: PageRoute, Page, names: named(register), named(registerPageOwnedServices))
public macro Page(_ path: String) = #externalMacro(module: "SwiftWebMacros", type: "PageMacro")

@attached(peer, names: arbitrary)
public macro ServerAction(_ path: String) = #externalMacro(module: "SwiftWebMacros", type: "ServerActionMacro")

@attached(peer, names: arbitrary)
public macro ServerAction(_ method: ServerActionMethod, _ path: String) = #externalMacro(module: "SwiftWebMacros", type: "ServerActionMacro")

@attached(extension, conformances: SwiftWebActorExporting, names: named(SwiftWebActorContract), named(swiftWebActorContractKey), named(_swiftWebActorContractTypeCheck))
public macro ResolvableActor(_ contract: Any.Type) = #externalMacro(module: "SwiftWebMacros", type: "ResolvableActorMacro")
