import Foundation
import SwiftHTML

package struct SwiftWebDevClientManifestSnapshotStore: Sendable {
    package let fileURL: URL

    package init(fileURL: URL) {
        self.fileURL = fileURL.standardizedFileURL
    }

    package init?(environment: [String: String] = ProcessInfo.processInfo.environment) {
        guard let eventLog = SwiftWebDevEventLog(environment: environment) else {
            return nil
        }
        self.init(fileURL: Self.fileURL(forEventLog: eventLog.fileURL))
    }

    package static func fileURL(for configuration: SwiftWebDevRuntimeConfiguration) -> URL {
        fileURL(forEventLog: SwiftWebDevEventLog.fileURL(for: configuration))
    }

    package func record(
        _ manifest: ClientBundleManifest,
        eventLog: SwiftWebDevEventLog? = SwiftWebDevEventLog()
    ) {
        do {
            try write(manifest)
        } catch {
            reportWriteFailure(error, eventLog: eventLog)
        }
    }

    package func write(_ manifest: ClientBundleManifest) throws {
        try FileManager.default.createDirectory(
            at: fileURL.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        let data = try encoder.encode(manifest)
        try data.write(to: fileURL, options: [.atomic])
    }

    package func read() throws -> ClientBundleManifest? {
        guard FileManager.default.fileExists(atPath: fileURL.path) else {
            return nil
        }
        let data = try Data(contentsOf: fileURL)
        return try JSONDecoder().decode(ClientBundleManifest.self, from: data)
    }

    private static func fileURL(forEventLog eventLogURL: URL) -> URL {
        eventLogURL
            .deletingLastPathComponent()
            .appendingPathComponent("client-manifest-snapshot.json")
            .standardizedFileURL
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

package struct SwiftWebDevClientManifestSchemaHashes: Sendable, Equatable {
    package let stateSchemaHash: String
    package let environmentSchemaHash: String

    package init(stateSchemaHash: String, environmentSchemaHash: String) {
        self.stateSchemaHash = stateSchemaHash
        self.environmentSchemaHash = environmentSchemaHash
    }

    package static let empty = SwiftWebDevClientManifestSchemaHashes(
        stateSchemaHash: StateSchema.hash([]),
        environmentSchemaHash: ClientEnvironmentSnapshot().schemaHash
    )
}
