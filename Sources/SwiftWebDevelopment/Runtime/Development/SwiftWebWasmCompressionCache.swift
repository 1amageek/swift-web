import CryptoKit
import Foundation

struct SwiftWebWasmCompressionCache: Sendable, Codable, Equatable {
    private struct Sidecar: Sendable, Codable, Equatable {
        let artifactContentHash: String
        let compressionSignature: String
        let bytes: Int
        let contentHash: String
    }

    private var sidecars: [String: Sidecar]

    private init(sidecars: [String: Sidecar] = [:]) {
        self.sidecars = sidecars
    }

    static func load(
        for artifactURL: URL,
        warnings: inout [String]
    ) -> SwiftWebWasmCompressionCache {
        let url = cacheURL(for: artifactURL)
        guard FileManager.default.fileExists(atPath: url.path) else {
            return SwiftWebWasmCompressionCache()
        }

        do {
            let data = try Data(contentsOf: url)
            return try JSONDecoder().decode(SwiftWebWasmCompressionCache.self, from: data)
        } catch {
            warnings.append(
                "ignored invalid WASM compression cache at \(url.path): \(String(describing: error))"
            )
            return SwiftWebWasmCompressionCache()
        }
    }

    func cachedBytes(
        extensionName: String,
        artifactContentHash: String,
        compressionSignature: String,
        sidecarURL: URL
    ) throws -> Int? {
        guard let sidecar = sidecars[extensionName],
              sidecar.artifactContentHash == artifactContentHash,
              sidecar.compressionSignature == compressionSignature,
              FileManager.default.fileExists(atPath: sidecarURL.path)
        else {
            return nil
        }

        let identity = try Self.sidecarIdentity(at: sidecarURL)
        guard identity.bytes == sidecar.bytes,
              identity.contentHash == sidecar.contentHash
        else {
            return nil
        }

        return identity.bytes
    }

    mutating func store(
        extensionName: String,
        artifactContentHash: String,
        compressionSignature: String,
        sidecarURL: URL
    ) throws -> Int {
        let identity = try Self.sidecarIdentity(at: sidecarURL)
        sidecars[extensionName] = Sidecar(
            artifactContentHash: artifactContentHash,
            compressionSignature: compressionSignature,
            bytes: identity.bytes,
            contentHash: identity.contentHash
        )
        return identity.bytes
    }

    mutating func remove(extensionName: String) {
        sidecars.removeValue(forKey: extensionName)
    }

    func write(for artifactURL: URL) throws {
        let url = Self.cacheURL(for: artifactURL)
        guard !sidecars.isEmpty else {
            if FileManager.default.fileExists(atPath: url.path) {
                try FileManager.default.removeItem(at: url)
            }
            return
        }

        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        let data = try encoder.encode(self)
        try data.write(to: url, options: [.atomic])
    }

    static func cacheURL(for artifactURL: URL) -> URL {
        URL(fileURLWithPath: artifactURL.path + ".compression.json")
    }

    private static func sidecarIdentity(at url: URL) throws -> (bytes: Int, contentHash: String) {
        let data = try Data(contentsOf: url, options: [.mappedIfSafe])
        let hash = SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined()
        return (data.count, hash)
    }
}
