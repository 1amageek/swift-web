#if canImport(FoundationEssentials)
import FoundationEssentials
#else
import Foundation
#endif
import HTTPTypes
import SwiftWebHost
import SwiftHTML

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
    public static func registerHost(on routes: any WebRoutesBuilder) -> [WebRoute] {
        [
            routes.get("__swiftweb", "wasm", "runtime-host.js") { req async throws -> WebResponse in
                let body = SwiftWebWasmRuntimeHostScript.source
                let etag = quotedETag("swiftweb-host-\(hostScriptVersion)")
                let headers = cacheValidationHeaders(
                    contentType: "text/javascript; charset=utf-8",
                    etag: etag
                )
                if matchesETag(req.headers[.ifNoneMatch], etag: etag) {
                    return WebResponse(status: .notModified, headers: headers, body: .empty)
                }
                return WebResponse(headers: headers, body: .init(string: body))
            },
            routes.get("__swiftweb", "wasm", "javascript-kit-runtime.js") { req async throws -> WebResponse in
                let body = try SwiftWebJavaScriptKitRuntimeScript.load()
                let etag = quotedETag("swiftweb-javascript-kit-\(contentHash(of: body))")
                let headers = cacheValidationHeaders(
                    contentType: "text/javascript; charset=utf-8",
                    etag: etag
                )
                if matchesETag(req.headers[.ifNoneMatch], etag: etag) {
                    return WebResponse(status: .notModified, headers: headers, body: .empty)
                }
                return WebResponse(headers: headers, body: .init(string: body))
            },
        ]
    }

    @discardableResult
    public static func registerManifest(
        on routes: any WebRoutesBuilder,
        path: String,
        manifest: ClientBundleManifest
    ) -> WebRoute {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        return routes.on(.get, webPathComponents(for: path)) { req async throws -> WebResponse in
            let data = try encoder.encode(manifest)
            let etag = quotedETag("swiftweb-manifest-\(contentHash(of: String(decoding: data, as: UTF8.self)))")
            let headers = cacheValidationHeaders(
                contentType: "application/json; charset=utf-8",
                etag: etag
            )
            if matchesETag(req.headers[.ifNoneMatch], etag: etag) {
                return WebResponse(status: .notModified, headers: headers, body: .empty)
            }
            return WebResponse(headers: headers, body: .init(data: data))
        }
    }

    @discardableResult
    public static func registerWasmAsset(
        on routes: any WebRoutesBuilder,
        path: String,
        fileURL: URL
    ) -> WebRoute {
        registerWasmAsset(on: routes, path: path) {
            fileURL
        }
    }

    @discardableResult
    public static func registerWasmAsset(
        on routes: any WebRoutesBuilder,
        path: String,
        fileURL: @escaping @Sendable () throws -> URL
    ) -> WebRoute {
        return routes.on(.get, webPathComponents(for: path)) { req async throws -> WebResponse in
            let resolvedFileURL = try fileURL()
            guard FileManager.default.fileExists(atPath: resolvedFileURL.path) else {
                throw Abort(.notFound, reason: "WASM asset was not found at \(resolvedFileURL.path)")
            }
            let asset = selectedWasmAsset(
                fileURL: resolvedFileURL,
                acceptEncoding: req.headers[HTTPField.Name("Accept-Encoding")!] ?? ""
            )
            let etag = try fileETag(for: asset.fileURL, contentEncoding: asset.contentEncoding)
            let headers = wasmAssetHeaders(etag: etag, contentEncoding: asset.contentEncoding)
            if matchesETag(req.headers[.ifNoneMatch], etag: etag) {
                return WebResponse(status: .notModified, headers: headers, body: .empty)
            }
            let data = try Data(
                contentsOf: asset.fileURL,
                options: [.mappedIfSafe]
            )
            return WebResponse(
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
        let gzipURL = URL(fileURLWithPath: fileURL.path + ".gz")
        let brotliQuality = acceptedEncodingQuality("br", in: acceptEncoding)
        let gzipQuality = acceptedEncodingQuality("gzip", in: acceptEncoding)

        if FileManager.default.fileExists(atPath: brotliURL.path),
           brotliQuality > 0,
           brotliQuality >= gzipQuality
        {
            return (brotliURL, "br")
        }

        if FileManager.default.fileExists(atPath: gzipURL.path), gzipQuality > 0 {
            return (gzipURL, "gzip")
        }

        return (fileURL, nil)
    }

    private static func webPathComponents(for path: String) -> [WebPathComponent] {
        path
            .split(separator: "/", omittingEmptySubsequences: true)
            .map { .constant(String($0)) }
    }

    private static func cacheValidationHeaders(
        contentType: String,
        etag: String
    ) -> HTTPFields {
        [
            .contentType: contentType,
            .cacheControl: "no-cache",
            .eTag: etag,
        ]
    }

    private static func wasmAssetHeaders(
        etag: String,
        contentEncoding: String?
    ) -> HTTPFields {
        var headers: HTTPFields = [
            .contentType: "application/wasm",
            .cacheControl: "no-cache",
            .eTag: etag,
            HTTPField.Name("Vary")!: "Accept-Encoding",
        ]
        if let contentEncoding {
            headers[HTTPField.Name("Content-Encoding")!] = contentEncoding
        }
        return headers
    }

    private static func fileETag(
        for fileURL: URL,
        contentEncoding: String?
    ) throws -> String {
        let attributes = try FileManager.default.attributesOfItem(atPath: fileURL.path)
        let modified = attributes[.modificationDate] as? Date
        let sizeValue: UInt64 =
            if let size = attributes[.size] as? UInt64 {
                size
            } else if let size = attributes[.size] as? Int {
                UInt64(size)
            } else {
                0
            }
        let modifiedNanoseconds = UInt64((modified?.timeIntervalSince1970 ?? 0) * 1_000_000_000)
        let encoding = contentEncoding ?? "identity"
        return quotedETag("swiftweb-wasm-\(encoding)-\(sizeValue)-\(modifiedNanoseconds)")
    }

    private static func quotedETag(_ value: String) -> String {
        "\"\(value)\""
    }

    /// Trims leading/trailing whitespace without `CharacterSet`:
    /// `whitespacesAndNewlines` is declared by both Foundation and
    /// FoundationEssentials on Linux, and transitive module loading makes the
    /// member lookup ambiguous there.
    private static func trimmedWhitespace(_ value: Substring) -> String {
        var slice = value
        while let first = slice.first, first.isWhitespace {
            slice = slice.dropFirst()
        }
        while let last = slice.last, last.isWhitespace {
            slice = slice.dropLast()
        }
        return String(slice)
    }

    private static func matchesETag(_ header: String?, etag: String) -> Bool {
        guard let header else {
            return false
        }
        return header
            .split(separator: ",")
            .map { trimmedWhitespace($0) }
            .contains { candidate in
                candidate == etag || candidate == "*"
            }
    }

    private static func acceptedEncodingQuality(_ encoding: String, in header: String) -> Double {
        let normalizedEncoding = encoding.lowercased()
        var explicitQuality: Double?
        var wildcardQuality: Double?

        for value in header.lowercased().split(separator: ",") {
            let parts = value
                .split(separator: ";")
                .map { trimmedWhitespace($0) }
            guard let name = parts.first else {
                continue
            }
            guard name == normalizedEncoding || name == "*" else {
                continue
            }

            let parsedQuality = parts
                .dropFirst()
                .compactMap(qualityParameter)
                .first
            let quality = parsedQuality ?? 1.0
            if name == normalizedEncoding {
                if let current = explicitQuality {
                    explicitQuality = max(current, quality)
                } else {
                    explicitQuality = quality
                }
            } else if let current = wildcardQuality {
                wildcardQuality = max(current, quality)
            } else {
                wildcardQuality = quality
            }
        }

        return explicitQuality ?? wildcardQuality ?? 0
    }

    private static func qualityParameter(_ value: String) -> Double? {
        let parts = value.split(separator: "=", maxSplits: 1)
        guard parts.count == 2,
              trimmedWhitespace(parts[0]) == "q"
        else {
            return nil
        }

        let rawValue = trimmedWhitespace(parts[1])
        guard let quality = Double(rawValue) else {
            return nil
        }
        return min(max(quality, 0), 1)
    }
}

package enum SwiftWebJavaScriptKitRuntimeScript {
    private static let swiftPMRelativePath = ".build/checkouts/JavaScriptKit/Plugins/PackageToJS/Templates/runtime.mjs"
    private static let xcodeRelativePath = "SourcePackages/checkouts/JavaScriptKit/Plugins/PackageToJS/Templates/runtime.mjs"

    package static func load() throws -> String {
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

    package static func scriptCandidates(
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
