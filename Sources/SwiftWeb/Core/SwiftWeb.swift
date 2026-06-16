@_exported import SwiftHTML
@_exported import Vapor

public typealias Environment = SwiftHTML.Environment

@attached(member, names: named(params), named(searchParams))
@attached(extension, conformances: PageRoute, Page, AppContent, names: named(register))
public macro Page(_ path: String) = #externalMacro(module: "SwiftWebMacros", type: "PageMacro")

@attached(peer, names: arbitrary)
public macro ServerAction(capabilityToken: String = "") = #externalMacro(module: "SwiftWebMacros", type: "ServerActionMacro")
