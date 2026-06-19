import Foundation

struct SwiftWebDevWasmArtifactCache: Sendable {
    private struct Metadata: Sendable, Codable {
        var inputHash: String
        var artifactHash: String
        var byteCount: Int64
        var storedAt: Date
        var lastAccessedAt: Date
    }

    private let rootDirectory: URL
    private let maxBytes: Int64
    private let isEnabled: Bool

    init(
        rootDirectory: URL? = nil,
        environment: [String: String] = ProcessInfo.processInfo.environment
    ) {
        self.rootDirectory = rootDirectory?.standardizedFileURL
            ?? Self.defaultRootDirectory(environment: environment)
        self.maxBytes = Self.maxBytes(environment: environment)
        self.isEnabled = Self.isEnabled(environment: environment)
    }

    func restore(inputHash: String, to artifactURL: URL) throws -> String? {
        guard isEnabled, maxBytes > 0 else {
            return nil
        }

        let directory = entryDirectory(inputHash: inputHash)
        let artifact = cachedArtifactURL(in: directory)
        let metadataURL = metadataURL(in: directory)
        guard FileManager.default.fileExists(atPath: artifact.path),
              FileManager.default.fileExists(atPath: metadataURL.path)
        else {
            return nil
        }

        var metadata = try readMetadata(from: metadataURL)
        guard metadata.inputHash == inputHash else {
            try FileManager.default.removeItem(at: directory)
            return nil
        }

        try FileManager.default.createDirectory(
            at: artifactURL.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        try replaceItem(at: artifactURL, withCopyOf: artifact)

        metadata.lastAccessedAt = Date()
        try writeMetadata(metadata, to: metadataURL)
        return metadata.artifactHash
    }

    func store(inputHash: String, artifactURL: URL, artifactHash: String) throws {
        guard isEnabled, maxBytes > 0 else {
            return
        }

        let attributes = try FileManager.default.attributesOfItem(atPath: artifactURL.path)
        let byteCount = (attributes[.size] as? NSNumber)?.int64Value ?? 0
        guard byteCount > 0, byteCount <= maxBytes else {
            return
        }

        let directory = entryDirectory(inputHash: inputHash)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        try replaceItem(at: cachedArtifactURL(in: directory), withCopyOf: artifactURL)

        let now = Date()
        try writeMetadata(
            Metadata(
                inputHash: inputHash,
                artifactHash: artifactHash,
                byteCount: byteCount,
                storedAt: now,
                lastAccessedAt: now
            ),
            to: metadataURL(in: directory)
        )
        try pruneIfNeeded()
    }

    private func pruneIfNeeded() throws {
        let entries = try cacheEntries()
        var totalBytes = entries.reduce(Int64(0)) { partial, entry in
            partial + entry.metadata.byteCount
        }
        guard totalBytes > maxBytes else {
            return
        }

        for entry in entries.sorted(by: { left, right in
            left.metadata.lastAccessedAt < right.metadata.lastAccessedAt
        }) {
            try FileManager.default.removeItem(at: entry.directory)
            totalBytes -= entry.metadata.byteCount
            if totalBytes <= maxBytes {
                break
            }
        }
    }

    private func cacheEntries() throws -> [(directory: URL, metadata: Metadata)] {
        guard FileManager.default.fileExists(atPath: rootDirectory.path) else {
            return []
        }

        let directories = try FileManager.default.contentsOfDirectory(
            at: rootDirectory,
            includingPropertiesForKeys: [.isDirectoryKey],
            options: [.skipsHiddenFiles]
        )
        var entries: [(directory: URL, metadata: Metadata)] = []
        for directory in directories {
            let values = try directory.resourceValues(forKeys: [.isDirectoryKey])
            guard values.isDirectory == true else {
                continue
            }
            let metadataURL = metadataURL(in: directory)
            guard FileManager.default.fileExists(atPath: metadataURL.path) else {
                continue
            }
            entries.append((directory, try readMetadata(from: metadataURL)))
        }
        return entries
    }

    private func readMetadata(from url: URL) throws -> Metadata {
        let data = try Data(contentsOf: url)
        return try JSONDecoder().decode(Metadata.self, from: data)
    }

    private func writeMetadata(_ metadata: Metadata, to url: URL) throws {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        let data = try encoder.encode(metadata)
        try data.write(to: url, options: [.atomic])
    }

    private func replaceItem(at destination: URL, withCopyOf source: URL) throws {
        let temporaryURL = destination
            .deletingLastPathComponent()
            .appendingPathComponent(".\(destination.lastPathComponent).\(UUID().uuidString).tmp")
        if FileManager.default.fileExists(atPath: temporaryURL.path) {
            try FileManager.default.removeItem(at: temporaryURL)
        }
        try FileManager.default.copyItem(at: source, to: temporaryURL)
        if FileManager.default.fileExists(atPath: destination.path) {
            try FileManager.default.removeItem(at: destination)
        }
        try FileManager.default.moveItem(at: temporaryURL, to: destination)
    }

    private func entryDirectory(inputHash: String) -> URL {
        rootDirectory
            .appendingPathComponent(inputHash, isDirectory: true)
            .standardizedFileURL
    }

    private func cachedArtifactURL(in directory: URL) -> URL {
        directory.appendingPathComponent("runtime.wasm")
    }

    private func metadataURL(in directory: URL) -> URL {
        directory.appendingPathComponent("metadata.json")
    }

    private static func isEnabled(environment: [String: String]) -> Bool {
        guard let rawValue = environment["SWIFTWEB_WASM_ARTIFACT_CACHE"]?.lowercased() else {
            return true
        }
        switch rawValue {
        case "0", "false", "no", "off":
            return false
        default:
            return true
        }
    }

    private static func maxBytes(environment: [String: String]) -> Int64 {
        guard let rawValue = environment["SWIFTWEB_WASM_ARTIFACT_CACHE_MAX_BYTES"],
              let value = Int64(rawValue)
        else {
            return 512 * 1024 * 1024
        }
        return max(value, 0)
    }

    private static func defaultRootDirectory(environment: [String: String]) -> URL {
        if let rawPath = environment["SWIFTWEB_WASM_ARTIFACT_CACHE_PATH"],
           !rawPath.isEmpty
        {
            return URL(fileURLWithPath: rawPath, isDirectory: true).standardizedFileURL
        }

        let homeDirectory = FileManager.default.homeDirectoryForCurrentUser
        return homeDirectory
            .appendingPathComponent("Library", isDirectory: true)
            .appendingPathComponent("Caches", isDirectory: true)
            .appendingPathComponent("SwiftWeb", isDirectory: true)
            .appendingPathComponent("wasm-artifacts", isDirectory: true)
            .appendingPathComponent("v1", isDirectory: true)
            .standardizedFileURL
    }
}
