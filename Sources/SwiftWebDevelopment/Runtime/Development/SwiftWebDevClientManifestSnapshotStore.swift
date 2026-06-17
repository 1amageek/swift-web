import Foundation
import SwiftHTML

struct SwiftWebDevClientManifestSnapshotStore: Sendable {
    let fileURL: URL

    init(fileURL: URL) {
        self.fileURL = fileURL.standardizedFileURL
    }

    init?(environment: [String: String] = ProcessInfo.processInfo.environment) {
        guard let eventLog = SwiftWebDevEventLog(environment: environment) else {
            return nil
        }
        self.init(fileURL: Self.fileURL(forEventLog: eventLog.fileURL))
    }

    static func fileURL(for configuration: SwiftWebDevRuntimeConfiguration) -> URL {
        fileURL(forEventLog: SwiftWebDevEventLog.fileURL(for: configuration))
    }

    func record(
        _ manifest: ClientBundleManifest,
        eventLog: SwiftWebDevEventLog? = SwiftWebDevEventLog()
    ) {
        do {
            try write(manifest)
        } catch {
            reportWriteFailure(error, eventLog: eventLog)
        }
    }

    func write(_ manifest: ClientBundleManifest) throws {
        try FileManager.default.createDirectory(
            at: fileURL.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        let data = try encoder.encode(manifest)
        try data.write(to: fileURL, options: [.atomic])
    }

    func read() throws -> ClientBundleManifest? {
        guard FileManager.default.fileExists(atPath: fileURL.path) else {
            return nil
        }
        let data = try Data(contentsOf: fileURL)
        return try JSONDecoder().decode(ClientBundleManifest.self, from: data)
    }

    func schemaHashes(for runtime: SwiftWebGeneratedWasmRuntime) throws -> SwiftWebDevClientManifestSchemaHashes {
        guard let manifest = try read() else {
            return .empty
        }

        let components = manifest.components.filter { component in
            component.bundleID == runtime.bundleID
                || runtime.componentTypeNames.contains { typeName in
                    typeNamesMatch(typeName, component.typeName)
                }
        }
        guard !components.isEmpty else {
            return .empty
        }

        return SwiftWebDevClientManifestSchemaHashes(
            stateSchemaHash: combinedHash(components.map(\.stateSchemaHash), empty: StateSchema.hash([])),
            environmentSchemaHash: combinedHash(
                components.map(\.environmentSchemaHash),
                empty: ClientEnvironmentSnapshot().schemaHash
            )
        )
    }

    private static func fileURL(forEventLog eventLogURL: URL) -> URL {
        eventLogURL
            .deletingLastPathComponent()
            .appendingPathComponent("client-manifest-snapshot.json")
            .standardizedFileURL
    }

    private func typeNamesMatch(_ left: String, _ right: String) -> Bool {
        left == right || left.hasSuffix(".\(right)") || right.hasSuffix(".\(left)")
    }

    private func combinedHash(_ hashes: [String], empty: String) -> String {
        let unique = Array(Set(hashes.filter { !$0.isEmpty })).sorted()
        guard !unique.isEmpty else {
            return empty
        }
        guard unique.count > 1 else {
            return unique[0]
        }
        return stableHash(unique.joined(separator: "\n"))
    }

    private func stableHash(_ value: String) -> String {
        var hash: UInt64 = 0xcbf29ce484222325
        for byte in value.utf8 {
            hash ^= UInt64(byte)
            hash &*= 0x100000001b3
        }
        return String(format: "%016llx", hash)
    }

    private func reportWriteFailure(_ error: any Error, eventLog: SwiftWebDevEventLog?) {
        let message = "SwiftWeb dev manifest snapshot write failed: \(String(describing: error))"

        if let eventLog {
            do {
                try eventLog.append(SwiftWebDevEvent(kind: .error, message: message))
                return
            } catch {
                writeStandardError("\(message); event log append failed: \(String(describing: error))\n")
                return
            }
        }

        writeStandardError("\(message)\n")
    }

    private func writeStandardError(_ message: String) {
        guard let data = message.data(using: .utf8) else {
            return
        }
        FileHandle.standardError.write(data)
    }
}

struct SwiftWebDevClientManifestSchemaHashes: Sendable, Equatable {
    let stateSchemaHash: String
    let environmentSchemaHash: String

    static let empty = SwiftWebDevClientManifestSchemaHashes(
        stateSchemaHash: StateSchema.hash([]),
        environmentSchemaHash: ClientEnvironmentSnapshot().schemaHash
    )
}
