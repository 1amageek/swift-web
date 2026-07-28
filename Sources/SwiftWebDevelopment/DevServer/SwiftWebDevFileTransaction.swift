import Foundation

package struct SwiftWebDevFileTransaction {
    private struct Snapshot {
        let originalURL: URL
        let backupURL: URL
        let existed: Bool
    }

    private let directory: URL
    private let snapshots: [Snapshot]

    package init(fileURLs: [URL]) throws {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("swiftweb-dev-transaction-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        var snapshots: [Snapshot] = []
        do {
            for (index, originalURL) in fileURLs.enumerated() {
                let backupURL = directory.appendingPathComponent(String(index))
                let existed = FileManager.default.fileExists(atPath: originalURL.path)
                if existed {
                    try FileManager.default.copyItem(at: originalURL, to: backupURL)
                }
                snapshots.append(
                    Snapshot(originalURL: originalURL, backupURL: backupURL, existed: existed)
                )
            }
        } catch {
            do {
                try FileManager.default.removeItem(at: directory)
            } catch {
                // Preserve the original snapshot failure, which identifies the
                // file that prevented the transaction from starting.
            }
            throw error
        }
        self.directory = directory
        self.snapshots = snapshots
    }

    package func rollback() throws {
        for snapshot in snapshots {
            if FileManager.default.fileExists(atPath: snapshot.originalURL.path) {
                try FileManager.default.removeItem(at: snapshot.originalURL)
            }
            if snapshot.existed {
                try FileManager.default.createDirectory(
                    at: snapshot.originalURL.deletingLastPathComponent(),
                    withIntermediateDirectories: true
                )
                try FileManager.default.copyItem(
                    at: snapshot.backupURL,
                    to: snapshot.originalURL
                )
            }
        }
    }

    package func finish() throws {
        if FileManager.default.fileExists(atPath: directory.path) {
            try FileManager.default.removeItem(at: directory)
        }
    }
}
