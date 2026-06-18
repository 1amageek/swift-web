import Foundation

public struct SwiftWebDevBuildArtifactCleaner: Sendable {
    public init() {}

    public func cleanGeneratedArtifacts(in packageDirectory: URL) throws -> CleanupReport {
        let swiftWebDirectory = packageDirectory
            .standardizedFileURL
            .appendingPathComponent(".swiftweb", isDirectory: true)
        guard FileManager.default.fileExists(atPath: swiftWebDirectory.path) else {
            return CleanupReport()
        }

        var report = CleanupReport()
        try removeMatchingDirectories(
            under: swiftWebDirectory,
            shouldRemove: shouldRemoveGeneratedBuildArtifact,
            report: &report
        )
        return report
    }

    public func cleanStoryboard(in packageDirectory: URL) throws -> CleanupReport {
        let storyboardDirectory = packageDirectory
            .standardizedFileURL
            .appendingPathComponent(".swiftweb", isDirectory: true)
            .appendingPathComponent("storyboard", isDirectory: true)
        return try removeDirectoryIfPresent(storyboardDirectory)
    }

    public func cleanSwiftPMBuild(in packageDirectory: URL) throws -> CleanupReport {
        let buildDirectory = packageDirectory
            .standardizedFileURL
            .appendingPathComponent(".build", isDirectory: true)
        return try removeDirectoryIfPresent(buildDirectory)
    }

    private func removeMatchingDirectories(
        under root: URL,
        shouldRemove: (URL, String) -> Bool,
        report: inout CleanupReport
    ) throws {
        guard let enumerator = FileManager.default.enumerator(
            at: root,
            includingPropertiesForKeys: [.isDirectoryKey],
            options: [.skipsPackageDescendants]
        ) else {
            return
        }

        for case let url as URL in enumerator {
            let values = try url.resourceValues(forKeys: [.isDirectoryKey])
            guard values.isDirectory == true else {
                continue
            }

            let name = url.lastPathComponent
            guard shouldRemove(url, name) else {
                continue
            }

            try removeGeneratedItem(at: url)
            report.removedPaths.append(url.path)
            enumerator.skipDescendants()
        }
    }

    private func removeDirectoryIfPresent(_ directory: URL) throws -> CleanupReport {
        guard FileManager.default.fileExists(atPath: directory.path) else {
            return CleanupReport()
        }
        try removeGeneratedItem(at: directory)
        return CleanupReport(removedPaths: [directory.path])
    }

    private func removeGeneratedItem(at url: URL) throws {
        do {
            try FileManager.default.removeItem(at: url)
        } catch {
            try removeGeneratedItemWithRM(at: url, originalError: error)
        }
    }

    private func removeGeneratedItemWithRM(at url: URL, originalError: any Error) throws {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/bin/rm")
        process.arguments = ["-rf", url.path]
        process.standardOutput = FileHandle.standardOutput
        process.standardError = FileHandle.standardError

        try process.run()
        process.waitUntilExit()

        if process.terminationStatus != 0 || FileManager.default.fileExists(atPath: url.path) {
            throw originalError
        }
    }

    private func shouldRemoveGeneratedBuildArtifact(_ url: URL, _ name: String) -> Bool {
        switch name {
        case ".build", "dev-build", "module-cache", "swiftpm-module-cache", "tmp", "wasm-tools":
            return true
        default:
            return false
        }
    }

    public struct CleanupReport: Sendable, Equatable {
        public var removedPaths: [String]

        public init(removedPaths: [String] = []) {
            self.removedPaths = removedPaths
        }

        public var isEmpty: Bool {
            removedPaths.isEmpty
        }

        public mutating func merge(_ other: CleanupReport) {
            removedPaths.append(contentsOf: other.removedPaths)
        }
    }
}
