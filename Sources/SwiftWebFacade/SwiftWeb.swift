@_exported import SwiftWebBrowserRuntime
@_exported import SwiftWebCore

@attached(member, names: named(params), named(searchParams))
@attached(extension, conformances: PageRoute, Page, names: named(register), named(registerPageOwnedServices))
public macro Page(_ path: String) = #externalMacro(module: "SwiftWebMacros", type: "PageMacro")

@attached(peer, names: arbitrary)
public macro ServerAction(_ path: String) = #externalMacro(module: "SwiftWebMacros", type: "ServerActionMacro")

@attached(peer, names: arbitrary)
public macro ServerAction(_ method: ServerActionMethod, _ path: String) = #externalMacro(module: "SwiftWebMacros", type: "ServerActionMacro")
