import Foundation
import HTTPTypes
import NIOCore
import Testing
import Vapor
import VaporTesting
import SwiftWebVapor

@testable import SwiftWeb
@testable import SwiftWebCore

@Suite
struct SwiftWebWasmRuntimeRoutesTests {
  @Test
  func servesBrotliSidecarWhenAccepted() async throws {
    try await withApplication { application, webApplication in
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
        on: webApplication.routes,
        path: "/assets/runtime.wasm",
        fileURL: wasmURL
      )

      var headers: HTTPFields = [:]
      headers[HTTPField.Name("Accept-Encoding")!] = "gzip, br"
      let response = try await sendRequest(application, webApplication,
        .get,
        "/assets/runtime.wasm",
        headers: headers
      )

      #expect(response.status == .ok)
      #expect(String(buffer: response.body) == "brotli")
      #expect(response.headers[HTTPField.Name("Content-Encoding")!] == "br")
      #expect(response.headers[HTTPField.Name("Vary")!] == "Accept-Encoding")
      #expect(response.headers[.acceptRanges] == nil)
    }
  }

  @Test
  func servesGzipWhenItHasHigherQualityThanBrotli() async throws {
    try await withApplication { application, webApplication in
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
        on: webApplication.routes,
        path: "/assets/runtime.wasm",
        fileURL: wasmURL
      )

      var headers: HTTPFields = [:]
      headers[HTTPField.Name("Accept-Encoding")!] = "br;q=0.1, gzip;q=1.0"
      let response = try await sendRequest(application, webApplication,
        .get,
        "/assets/runtime.wasm",
        headers: headers
      )

      #expect(response.status == .ok)
      #expect(String(buffer: response.body) == "gzip")
      #expect(response.headers[HTTPField.Name("Content-Encoding")!] == "gzip")
    }
  }

  @Test
  func servesRawWasmWhenEncodingIsNotAccepted() async throws {
    try await withApplication { application, webApplication in
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
        on: webApplication.routes,
        path: "/assets/runtime.wasm",
        fileURL: wasmURL
      )

      var headers: HTTPFields = [:]
      headers[HTTPField.Name("Accept-Encoding")!] = "gzip;q=0"
      let response = try await sendRequest(application, webApplication,
        .get,
        "/assets/runtime.wasm",
        headers: headers
      )

      #expect(response.status == .ok)
      #expect(String(buffer: response.body) == "raw")
      #expect(response.headers[HTTPField.Name("Content-Encoding")!] == nil)
    }
  }

  @Test
  func wasmAssetSupportsETagRevalidation() async throws {
    try await withApplication { application, webApplication in
      let root = try temporaryDirectory()
      defer {
        do {
          try FileManager.default.removeItem(at: root)
        } catch {}
      }
      let wasmURL = root.appendingPathComponent("runtime.wasm")
      try Data("raw".utf8).write(to: wasmURL)
      SwiftWebWasmRuntimeRoutes.registerWasmAsset(
        on: webApplication.routes,
        path: "/assets/runtime.wasm",
        fileURL: wasmURL
      )

      let first = try await sendRequest(application, webApplication,
        .get,
        "/assets/runtime.wasm"
      )
      let etag = try #require(first.headers[.eTag])

      var headers: HTTPFields = [:]
      headers[.ifNoneMatch] = etag
      let second = try await sendRequest(application, webApplication,
        .get,
        "/assets/runtime.wasm",
        headers: headers
      )

      #expect(first.status == .ok)
      #expect(String(buffer: first.body) == "raw")
      #expect(first.headers[.cacheControl] == "no-cache")
      #expect(second.status == .notModified)
      #expect(String(buffer: second.body).isEmpty)
      #expect(second.headers[.eTag] == etag)
      #expect(second.headers[HTTPField.Name("Vary")!] == "Accept-Encoding")
    }
  }

  @Test
  func runtimeHostScriptSupportsETagRevalidation() async throws {
    try await withApplication { application, webApplication in
      SwiftWebWasmRuntimeRoutes.registerHost(on: webApplication.routes)

      let first = try await sendRequest(application, webApplication,
        .get,
        SwiftWebWasmRuntimeRoutes.hostScriptPath
      )
      let etag = try #require(first.headers[.eTag])

      var headers: HTTPFields = [:]
      headers[.ifNoneMatch] = etag
      let second = try await sendRequest(application, webApplication,
        .get,
        SwiftWebWasmRuntimeRoutes.hostScriptPath,
        headers: headers
      )

      #expect(first.status == .ok)
      #expect(String(buffer: first.body).contains("SwiftWebWasmRuntime"))
      #expect(second.status == .notModified)
      #expect(String(buffer: second.body).isEmpty)
      #expect(second.headers[.eTag] == etag)
    }
  }

  @Test
  func explicitEncodingRejectionOverridesWildcardAcceptance() async throws {
    try await withApplication { application, webApplication in
      let root = try temporaryDirectory()
      defer {
        do {
          try FileManager.default.removeItem(at: root)
        } catch {}
      }
      let wasmURL = root.appendingPathComponent("runtime.wasm")
      try Data("raw".utf8).write(to: wasmURL)
      try Data("brotli".utf8).write(to: URL(fileURLWithPath: wasmURL.path + ".br"))
      SwiftWebWasmRuntimeRoutes.registerWasmAsset(
        on: webApplication.routes,
        path: "/assets/runtime.wasm",
        fileURL: wasmURL
      )

      var headers: HTTPFields = [:]
      headers[HTTPField.Name("Accept-Encoding")!] = "br;q=0, *;q=1"
      let response = try await sendRequest(application, webApplication,
        .get,
        "/assets/runtime.wasm",
        headers: headers
      )

      #expect(response.status == .ok)
      #expect(String(buffer: response.body) == "raw")
      #expect(response.headers[HTTPField.Name("Content-Encoding")!] == nil)
    }
  }

  @Test
  func resolvesWasmArtifactWhenRequestArrivesAfterBuild() async throws {
    try await withApplication { application, webApplication in
      let root = try temporaryDirectory()
      defer {
        do {
          try FileManager.default.removeItem(at: root)
        } catch {}
      }
      let package = root.appendingPathComponent("generated/wasm", isDirectory: true)
      let source = package.appendingPathComponent("Sources/Runtime/Runtime.swift")
      let scratch = root.appendingPathComponent("generated/.build/server/wasm", isDirectory: true)
      let wasmURL =
        scratch
        .appendingPathComponent(
          "wasm32-unknown-wasip1/release/storyboard-preview-wasm-runtime.wasm")
      try write(
        """
        // swift-tools-version: 6.3
        import PackageDescription

        let package = Package(name: "GeneratedWasm")
        """,
        to: package.appendingPathComponent("Package.swift")
      )
      try write("public struct Runtime {}", to: source)
      let artifact = SwiftPMWasmArtifact.location(
        anchorFile: package.appendingPathComponent("Package.swift").path,
        target: "StoryboardPreviewWasmRuntime",
        artifactName: "storyboard-preview-wasm-runtime",
        scratchDirectory: scratch
      )
      SwiftWebWasmRuntimeRoutes.registerWasmAsset(
        on: webApplication.routes,
        path: "/assets/storyboard-preview-wasm-runtime.wasm",
        fileURL: {
          try artifact.url()
        }
      )
      try write("wasm", to: wasmURL)

      let response = try await sendRequest(application, webApplication,
        .get,
        "/assets/storyboard-preview-wasm-runtime.wasm"
      )

      #expect(response.status == .ok)
      #expect(String(buffer: response.body) == "wasm")
    }
  }

  private func withApplication(
    _ body: (Vapor.Application, VaporWebApplication) async throws -> Void
  ) async throws {
    let application = try await Vapor.Application()
    let webApplication = VaporWebApplication(application)
    do {
      try await body(application, webApplication)
      try await application.shutdown()
    } catch {
      try await application.shutdown()
      throw error
    }
  }

  private func sendRequest(
    _ application: Vapor.Application,
    _ webApplication: VaporWebApplication,
    _ method: HTTPRequest.Method,
    _ path: String,
    headers: HTTPFields = [:]
  ) async throws -> TestingHTTPResponse {
    webApplication.lowerPendingRoutes()
    return try await application.testing().sendRequest(method, path, headers: headers)
  }

  private func temporaryDirectory() throws -> URL {
    let url = FileManager.default.temporaryDirectory
      .appendingPathComponent(
        "SwiftWebWasmRuntimeRoutesTests-\(UUID().uuidString)", isDirectory: true)
    try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
    return url
  }

  private func write(_ contents: String, to url: URL) throws {
    try FileManager.default.createDirectory(
      at: url.deletingLastPathComponent(),
      withIntermediateDirectories: true
    )
    try contents.write(to: url, atomically: true, encoding: .utf8)
  }
}
