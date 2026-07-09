@_exported import SwiftHTML
@_exported import SwiftWebHost
@_exported import HTTPTypes

public typealias Environment = SwiftHTML.Environment
public typealias Application = any WebApplicationProtocol
public typealias AsyncBodyStreamWriter = WebBodyWriter
public typealias File = WebFile
public typealias HTTPBodyStreamStrategy = WebBodyStreamStrategy
public typealias HTTPStatus = HTTPResponse.Status
public typealias Middleware = WebMiddleware
public typealias Middlewares = WebMiddlewares
public typealias Request = WebRequest
public typealias Responder = WebResponder
public typealias Response = WebResponse
public typealias ResponseEncodable = WebResponseEncodable
public typealias Route = WebRoute
public typealias RoutesBuilder = WebRoutesBuilder
public typealias StorageKey = WebStorageKey
