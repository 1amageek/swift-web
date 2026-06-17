import Foundation
import HTTPTypes
import NIOCore
@testable import SwiftWeb
import Testing
import Vapor
import VaporTesting

@Suite
struct SwiftWebWasmRuntimeRoutesTests {
    @Test
    func servesBrotliSidecarWhenAccepted() async throws {
        try await withApplication { application in
            let root = try temporaryDirectory()
            defer {
                do {
                    try FileManager.default.removeItem(at: root)
                } catch {}
            }
            let wasmURL = root.appendingPathComponent("runtime.wasm")
            try Data("raw".utf8).write(to: wasmURL)
            try Data("gzip".utf8).write(to: URL(fileURLWithPath: wasmURL.path + ".gz"))
            try Data("brotli".utf8).write(to: URL(fileURLWithPath: wasmURL.path + ".br"))
            SwiftWebWasmRuntimeRoutes.registerWasmAsset(
                on: application,
                path: "/assets/runtime.wasm",
                fileURL: wasmURL
            )

            var headers: HTTPFields = [:]
            headers[HTTPField.Name("Accept-Encoding")!] = "gzip, br"
            let response = try await application.testing().sendRequest(
                .get,
                "/assets/runtime.wasm",
                headers: headers
            )

            #expect(response.status == .ok)
            #expect(String(buffer: response.body) == "brotli")
            #expect(response.headers[HTTPField.Name("Content-Encoding")!] == "br")
            #expect(response.headers[HTTPField.Name("Vary")!] == "Accept-Encoding")
        }
    }

    @Test
    func servesRawWasmWhenEncodingIsNotAccepted() async throws {
        try await withApplication { application in
            let root = try temporaryDirectory()
            defer {
                do {
                    try FileManager.default.removeItem(at: root)
                } catch {}
            }
            let wasmURL = root.appendingPathComponent("runtime.wasm")
            try Data("raw".utf8).write(to: wasmURL)
            try Data("gzip".utf8).write(to: URL(fileURLWithPath: wasmURL.path + ".gz"))
            SwiftWebWasmRuntimeRoutes.registerWasmAsset(
                on: application,
                path: "/assets/runtime.wasm",
                fileURL: wasmURL
            )

            var headers: HTTPFields = [:]
            headers[HTTPField.Name("Accept-Encoding")!] = "gzip;q=0"
            let response = try await application.testing().sendRequest(
                .get,
                "/assets/runtime.wasm",
                headers: headers
            )

            #expect(response.status == .ok)
            #expect(String(buffer: response.body) == "raw")
            #expect(response.headers[HTTPField.Name("Content-Encoding")!] == nil)
        }
    }

    private func withApplication(
        _ body: (Application) async throws -> Void
    ) async throws {
        let application = try await Application()
        do {
            try await body(application)
            try await application.shutdown()
        } catch {
            try await application.shutdown()
            throw error
        }
    }

    private func temporaryDirectory() throws -> URL {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("SwiftWebWasmRuntimeRoutesTests-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        return url
    }
}
