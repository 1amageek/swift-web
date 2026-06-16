import Foundation
import SwiftHTML
import Vapor

public enum SwiftWebWasmRuntimeRoutes {
    public static let hostScriptPath = "/__swiftweb/wasm/runtime-host.js"
    public static let hostScriptVersion = "18"
    public static let versionedHostScriptPath = "\(hostScriptPath)?v=\(hostScriptVersion)"
    public static let javaScriptKitRuntimePath = "/__swiftweb/wasm/javascript-kit-runtime.js"
    public static let javaScriptKitRuntimeVersion = "1"
    public static let versionedJavaScriptKitRuntimePath = "\(javaScriptKitRuntimePath)?v=\(javaScriptKitRuntimeVersion)"

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
            let data = try Data(
                contentsOf: fileURL,
                options: [.mappedIfSafe]
            )
            return Response(
                headers: [
                    .contentType: "application/wasm",
                    .cacheControl: "no-cache",
                    .acceptRanges: "bytes",
                ],
                body: .init(data: data)
            )
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
