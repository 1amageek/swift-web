@_exported import SwiftHTML
@_exported import SwiftWebHost
@_exported import HTTPTypes

public typealias Environment = SwiftHTML.Environment
public typealias Application = any ApplicationProtocol
public typealias AsyncBodyStreamWriter = BodyWriter
public typealias HTTPBodyStreamStrategy = BodyStreamStrategy
public typealias HTTPStatus = HTTPResponse.Status
