import Foundation
import HTTPTypes
import SwiftHTML
import Vapor

public enum SwiftWebWasmRuntimeRoutes {
    public static let hostScriptPath = "/__swiftweb/wasm/runtime-host.js"
    /// Cache-bust token derived from the host script content.
    ///
    /// The token is a deterministic content hash of the served script, so any edit
    /// to `SwiftWebWasmRuntimeHostScript.source` changes the URL automatically and
    /// browsers refetch. Deriving it from the content removes the hand-maintained
    /// version number that previously had to be bumped — and its assertions
    /// rewritten — on every script change.
    public static let hostScriptVersion = contentHash(of: SwiftWebWasmRuntimeHostScript.source)
    public static let versionedHostScriptPath = "\(hostScriptPath)?v=\(hostScriptVersion)"
    public static let javaScriptKitRuntimePath = "/__swiftweb/wasm/javascript-kit-runtime.js"
    public static let javaScriptKitRuntimeVersion = "1"
    public static let versionedJavaScriptKitRuntimePath = "\(javaScriptKitRuntimePath)?v=\(javaScriptKitRuntimeVersion)"

    /// A deterministic FNV-1a 64-bit content hash rendered as hex.
    ///
    /// Unlike `Hasher`, the result is stable across processes, so the cache-bust
    /// token is reproducible between the server build and every request rather
    /// than changing per launch.
    static func contentHash(of string: String) -> String {
        var hash: UInt64 = 0xcbf2_9ce4_8422_2325
        for byte in string.utf8 {
            hash ^= UInt64(byte)
            hash = hash &* 0x0000_0100_0000_01b3
        }
        return String(hash, radix: 16)
    }

    @discardableResult
    public static func registerHost(on routes: any RoutesBuilder) -> [Route] {
        [
            routes.get("__swiftweb", "wasm", "runtime-host.js") { _ async throws -> Response in
                Response(
                    headers: [
                        .contentType: "text/javascript; charset=utf-8",
                        .cacheControl: "no-cache",
                    ],
                    body: .init(string: SwiftWebWasmRuntimeHostScript.source)
                )
            },
            routes.get("__swiftweb", "wasm", "javascript-kit-runtime.js") { _ async throws -> Response in
                Response(
                    headers: [
                        .contentType: "text/javascript; charset=utf-8",
                        .cacheControl: "no-cache",
                    ],
                    body: .init(string: try SwiftWebJavaScriptKitRuntimeScript.load())
                )
            },
        ]
    }

    @discardableResult
    public static func registerManifest(
        on routes: any RoutesBuilder,
        path: String,
        manifest: ClientBundleManifest
    ) -> Route {
        let routePath = RoutePath(path)
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        return routes.on(.get, routePath.vaporComponents) { _ async throws -> Response in
            let data = try encoder.encode(manifest)
            return Response(
                headers: [
                    .contentType: "application/json; charset=utf-8",
                    .cacheControl: "no-cache",
                ],
                body: .init(data: data)
            )
        }
    }

    @discardableResult
    public static func registerWasmAsset(
        on routes: any RoutesBuilder,
        path: String,
        fileURL: URL
    ) -> Route {
        let routePath = RoutePath(path)
        return routes.on(.get, routePath.vaporComponents) { req async throws -> Response in
            guard FileManager.default.fileExists(atPath: fileURL.path) else {
                throw Abort(.notFound, reason: "WASM asset was not found at \(fileURL.path)")
            }
            let asset = selectedWasmAsset(
                fileURL: fileURL,
                acceptEncoding: req.headers[HTTPField.Name("Accept-Encoding")!] ?? ""
            )
            let data = try Data(
                contentsOf: asset.fileURL,
                options: [.mappedIfSafe]
            )
            var headers: HTTPFields = [
                .contentType: "application/wasm",
                .cacheControl: "no-cache",
                .acceptRanges: "bytes",
                HTTPField.Name("Vary")!: "Accept-Encoding",
            ]
            if let contentEncoding = asset.contentEncoding {
                headers[HTTPField.Name("Content-Encoding")!] = contentEncoding
            }
            return Response(
                headers: headers,
                body: .init(data: data)
            )
        }
    }

    private static func selectedWasmAsset(
        fileURL: URL,
        acceptEncoding: String
    ) -> (fileURL: URL, contentEncoding: String?) {
        let brotliURL = URL(fileURLWithPath: fileURL.path + ".br")
        if acceptsEncoding("br", in: acceptEncoding),
           FileManager.default.fileExists(atPath: brotliURL.path)
        {
            return (brotliURL, "br")
        }

        let gzipURL = URL(fileURLWithPath: fileURL.path + ".gz")
        if acceptsEncoding("gzip", in: acceptEncoding),
           FileManager.default.fileExists(atPath: gzipURL.path)
        {
            return (gzipURL, "gzip")
        }

        return (fileURL, nil)
    }

    private static func acceptsEncoding(_ encoding: String, in header: String) -> Bool {
        header
            .lowercased()
            .split(separator: ",")
            .contains { value in
                let parts = value
                    .split(separator: ";")
                    .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
                guard let name = parts.first else {
                    return false
                }
                if parts.contains("q=0") || parts.contains("q=0.0") {
                    return false
                }
                return name == encoding || name == "*"
            }
    }
}

enum SwiftWebJavaScriptKitRuntimeScript {
    private static let swiftPMRelativePath = ".build/checkouts/JavaScriptKit/Plugins/PackageToJS/Templates/runtime.mjs"
    private static let xcodeRelativePath = "SourcePackages/checkouts/JavaScriptKit/Plugins/PackageToJS/Templates/runtime.mjs"

    static func load() throws -> String {
        let fileManager = FileManager.default
        let candidates = scriptCandidates(
            currentDirectory: URL(fileURLWithPath: fileManager.currentDirectoryPath),
            sourceFile: URL(fileURLWithPath: #filePath),
            fileManager: fileManager
        )

        for candidate in candidates where fileManager.fileExists(atPath: candidate.path) {
            let source = try String(contentsOf: candidate, encoding: .utf8)
            return patchCommandABICompatibility(in: source)
        }

        throw Abort(
            .internalServerError,
            reason: "JavaScriptKit runtime script was not found. Build the package once so SwiftPM checks out JavaScriptKit."
        )
    }

    static func scriptCandidates(
        currentDirectory: URL,
        sourceFile: URL,
        fileManager: FileManager
    ) -> [URL] {
        var candidates: [URL] = []
        var seen = Set<String>()

        func append(_ candidate: URL) {
            let standardized = candidate.standardizedFileURL
            if seen.insert(standardized.path).inserted {
                candidates.append(standardized)
            }
        }

        for root in ancestorDirectories(from: currentDirectory) {
            append(root.appendingPathComponent(swiftPMRelativePath))
            append(root.appendingPathComponent(xcodeRelativePath))
        }

        for root in packageRoots(from: currentDirectory, fileManager: fileManager) {
            append(root.appendingPathComponent(swiftPMRelativePath))
        }

        for root in packageRoots(from: sourceFile.deletingLastPathComponent(), fileManager: fileManager) {
            append(root.appendingPathComponent(swiftPMRelativePath))
        }

        return candidates
    }

    private static func ancestorDirectories(from start: URL) -> [URL] {
        var directories: [URL] = []
        var directory = start.standardizedFileURL

        while true {
            directories.append(directory)

            let parent = directory.deletingLastPathComponent().standardizedFileURL
            if parent.path == directory.path {
                break
            }
            directory = parent
        }

        return directories
    }

    private static func packageRoots(from start: URL, fileManager: FileManager) -> [URL] {
        var roots: [URL] = []
        var seen = Set<String>()
        var directory = start.standardizedFileURL

        while true {
            let packageFile = directory.appendingPathComponent("Package.swift")
            if fileManager.fileExists(atPath: packageFile.path), seen.insert(directory.path).inserted {
                roots.append(directory)
            }

            let parent = directory.deletingLastPathComponent().standardizedFileURL
            if parent.path == directory.path {
                break
            }
            directory = parent
        }

        return roots
    }

    private static func patchCommandABICompatibility(in source: String) -> String {
        let reactorGuard = """
                if (typeof this.exports._start === "function") {
                    throw new Error(`JavaScriptKit supports only WASI reactor ABI.
                        Please make sure you are building with:
                        -Xswiftc -Xclang-linker -Xswiftc -mexec-model=reactor
                        `);
                }
        """
        return source.replacingOccurrences(of: reactorGuard, with: "")
    }
}
