#if os(WASI)
#if canImport(FoundationEssentials)
import FoundationEssentials
#elseif canImport(Foundation)
import Foundation
#endif
import JavaScriptKit
import SwiftWebActors

public struct JavaScriptKitWebActorTransport: WebActorTransport {
    public let endpointPath: String

    public init(endpointPath: String = "/_swiftweb/actors/invoke") {
        self.endpointPath = endpointPath
    }

    public func call(_ envelope: InvocationEnvelope) async throws -> ResponseEnvelope {
        let bodyData = try JSONEncoder().encode(envelope)
        guard let body = String(data: bodyData, encoding: .utf8) else {
            throw RuntimeError.serializationFailed("Actor invocation envelope is not valid UTF-8 JSON")
        }
        guard let fetch = JSObject.global.fetch.function else {
            throw RuntimeError.transportFailed("Browser fetch API is not available")
        }

        let headers = JSObject.global.Object.function!.new()
        headers["Content-Type"] = "application/json"
        headers["Accept"] = "application/json"
        if let csrfHeader = csrfHeader() {
            headers[csrfHeader.name] = .string(JSString(csrfHeader.value))
        }

        let options = JSObject.global.Object.function!.new()
        options["method"] = "POST"
        options["credentials"] = "same-origin"
        options["headers"] = .object(headers)
        options["body"] = .string(body)

        guard let responsePromise = JSPromise(from: fetch(endpointPath, options)) else {
            throw RuntimeError.transportFailed("Browser fetch did not return a Promise")
        }
        let response = try await responsePromise.swiftWebValue
        let status = Int(response.status.number ?? 0)

        guard let textPromise = JSPromise(from: response.text()) else {
            throw RuntimeError.transportFailed("Response.text() did not return a Promise")
        }
        let textValue = try await textPromise.swiftWebValue
        guard let text = textValue.string else {
            throw RuntimeError.transportFailed("Actor invocation response body is not text")
        }
        guard response.ok.boolean == true else {
            throw RuntimeError.transportFailed("Actor invocation failed with HTTP \(status): \(text)")
        }

        return try JSONDecoder().decode(ResponseEnvelope.self, from: Data(text.utf8))
    }

    private func csrfHeader() -> (name: String, value: String)? {
        guard let runtime = JSObject.global.__swiftWebWasmRuntime.object else {
            return nil
        }
        let security = runtime.security
        guard let token = security.csrfToken.string else {
            return nil
        }
        return (
            security.csrfHeaderName.string ?? "X-CSRF-Token",
            token
        )
    }
}

private extension JSPromise {
    var swiftWebValue: JSValue {
        get async throws {
            let result: Swift.Result<JSValue, RuntimeError> = await withUnsafeContinuation { continuation in
                _ = then(
                    success: { value in
                        continuation.resume(returning: .success(value))
                        return JSValue.undefined
                    },
                    failure: { reason in
                        continuation.resume(returning: .failure(
                            .transportFailed("JavaScript Promise rejected: \(String(describing: reason))")
                        ))
                        return JSValue.undefined
                    }
                )
            }
            return try result.get()
        }
    }
}
#endif
