import Foundation

public enum ActorGeneratedSourceWriter {
    private static let manifestName = ".actor-system-generated-files.json"

    private struct OwnershipManifest: Codable {
        struct File: Codable {
            let relativePath: String
            let contentDigest: String
        }

        static let currentFormatVersion = 1

        let formatVersion: Int
        let files: [File]

        init(sources: [GeneratedActorSource]) {
            self.formatVersion = Self.currentFormatVersion
            self.files = sources
                .map {
                    File(
                        relativePath: $0.relativePath,
                        contentDigest: ActorStableHash.digest($0.contents)
                    )
                }
                .sorted { $0.relativePath < $1.relativePath }
        }
    }

    public static func write(
        _ sources: [GeneratedActorSource],
        to outputDirectory: URL
    ) throws -> [URL] {
        try write(sources, to: outputDirectory, committing: {})
    }

    static func write(
        _ sources: [GeneratedActorSource],
        to outputDirectory: URL,
        committing commit: () throws -> Void
    ) throws -> [URL] {
        let fileManager = FileManager.default
        let parent = outputDirectory.deletingLastPathComponent()
        try fileManager.createDirectory(
            at: parent,
            withIntermediateDirectories: true
        )
        try validateOwnedOutputDirectory(outputDirectory, fileManager: fileManager)

        let transactionID = UUID().uuidString
        let stagingDirectory = parent.appendingPathComponent(
            ".actor-system-staging-\(transactionID)",
            isDirectory: true
        )
        let backupDirectory = parent.appendingPathComponent(
            ".actor-system-backup-\(transactionID)",
            isDirectory: true
        )
        defer {
            removeIfPresent(stagingDirectory, fileManager: fileManager)
            removeIfPresent(backupDirectory, fileManager: fileManager)
        }

        let relativePaths = Set(sources.map(\.relativePath))
        guard relativePaths.count == sources.count else {
            throw ActorGenerationError.sourceWriteFailure(
                path: outputDirectory.path,
                reason: "Generated source paths must be unique"
            )
        }
        try fileManager.createDirectory(
            at: stagingDirectory,
            withIntermediateDirectories: true
        )
        for source in sources {
            let url = try generatedURL(
                relativePath: source.relativePath,
                outputDirectory: stagingDirectory
            )
            try fileManager.createDirectory(
                at: url.deletingLastPathComponent(),
                withIntermediateDirectories: true
            )
            do {
                try source.contents.write(to: url, atomically: true, encoding: .utf8)
            } catch {
                throw ActorGenerationError.sourceWriteFailure(
                    path: url.path,
                    reason: String(describing: error)
                )
            }
        }
        let manifestEncoder = JSONEncoder()
        manifestEncoder.outputFormatting = [.sortedKeys]
        let manifestData = try manifestEncoder.encode(
            OwnershipManifest(sources: sources)
        )
        try manifestData.write(
            to: stagingDirectory.appendingPathComponent(manifestName),
            options: .atomic
        )

        let outputExists = fileManager.fileExists(atPath: outputDirectory.path)
        if outputExists {
            try fileManager.moveItem(at: outputDirectory, to: backupDirectory)
        }
        do {
            try fileManager.moveItem(at: stagingDirectory, to: outputDirectory)
        } catch {
            if outputExists,
               fileManager.fileExists(atPath: backupDirectory.path),
               !fileManager.fileExists(atPath: outputDirectory.path) {
                do {
                    try fileManager.moveItem(at: backupDirectory, to: outputDirectory)
                } catch {
                    throw ActorGenerationError.sourceWriteFailure(
                        path: outputDirectory.path,
                        reason: "Generation failed and rollback also failed: \(error)"
                    )
                }
            }
            throw ActorGenerationError.sourceWriteFailure(
                path: outputDirectory.path,
                reason: String(describing: error)
            )
        }

        do {
            try commit()
        } catch {
            do {
                try fileManager.removeItem(at: outputDirectory)
                if outputExists {
                    try fileManager.moveItem(at: backupDirectory, to: outputDirectory)
                }
            } catch let rollbackError {
                throw ActorGenerationError.sourceWriteFailure(
                    path: outputDirectory.path,
                    reason: "Commit failed (\(error)); rollback also failed (\(rollbackError))"
                )
            }
            throw error
        }

        return try sources.map { source in
            try generatedURL(
                relativePath: source.relativePath,
                outputDirectory: outputDirectory
            )
        }.sorted { $0.path < $1.path }
    }

    private static func validateOwnedOutputDirectory(
        _ outputDirectory: URL,
        fileManager: FileManager
    ) throws {
        guard fileManager.fileExists(atPath: outputDirectory.path) else {
            return
        }
        let outputValues = try outputDirectory.resourceValues(
            forKeys: [.isDirectoryKey, .isSymbolicLinkKey]
        )
        guard outputValues.isDirectory == true,
              outputValues.isSymbolicLink != true
        else {
            throw ActorGenerationError.sourceWriteFailure(
                path: outputDirectory.path,
                reason: "The generated output path must be a real directory"
            )
        }
        let contents = try fileManager.contentsOfDirectory(
            at: outputDirectory,
            includingPropertiesForKeys: nil
        )
        guard !contents.isEmpty else {
            return
        }
        let manifestURL = outputDirectory.appendingPathComponent(manifestName)
        guard fileManager.fileExists(atPath: manifestURL.path) else {
            throw ActorGenerationError.sourceWriteFailure(
                path: outputDirectory.path,
                reason: "The output directory is not owned by actor-system generation"
            )
        }
        let manifestData = try Data(contentsOf: manifestURL)
        var expectedPaths: Set<String> = []
        var expectedDigests: [String: String] = [:]
        do {
            let ownershipManifest = try JSONDecoder().decode(
                OwnershipManifest.self,
                from: manifestData
            )
            guard ownershipManifest.formatVersion == OwnershipManifest.currentFormatVersion else {
                throw ActorGenerationError.sourceWriteFailure(
                    path: manifestURL.path,
                    reason: "The generated output manifest format is unsupported"
                )
            }
            expectedDigests = Dictionary(
                uniqueKeysWithValues: ownershipManifest.files.map {
                    ($0.relativePath, $0.contentDigest)
                }
            )
            guard expectedDigests.count == ownershipManifest.files.count else {
                throw ActorGenerationError.sourceWriteFailure(
                    path: manifestURL.path,
                    reason: "The generated output manifest contains duplicate paths"
                )
            }
            expectedPaths = Set(expectedDigests.keys)
        } catch let error as ActorGenerationError {
            throw error
        } catch {
            // Format 0 recorded only owned paths. Accept it once so existing
            // generated directories can be transactionally upgraded to the
            // digest-bearing manifest written by this version.
            do {
                let legacyPaths = try JSONDecoder().decode([String].self, from: manifestData)
                expectedPaths = Set(legacyPaths)
                expectedDigests = [:]
                guard expectedPaths.count == legacyPaths.count else {
                    throw ActorGenerationError.sourceWriteFailure(
                        path: manifestURL.path,
                        reason: "The legacy generated output manifest contains duplicate paths"
                    )
                }
            } catch let legacyError {
                throw ActorGenerationError.sourceWriteFailure(
                    path: manifestURL.path,
                    reason: "The generated output manifest is invalid: \(legacyError)"
                )
            }
        }
        var actualPaths: Set<String> = []
        let canonicalOutputComponents = outputDirectory
            .resolvingSymlinksInPath()
            .standardizedFileURL
            .pathComponents
        guard let enumerator = fileManager.enumerator(
            at: outputDirectory,
            includingPropertiesForKeys: [.isDirectoryKey, .isSymbolicLinkKey]
        ) else {
            throw ActorGenerationError.sourceWriteFailure(
                path: outputDirectory.path,
                reason: "The generated output directory cannot be enumerated"
            )
        }
        for case let url as URL in enumerator {
            let values = try url.resourceValues(forKeys: [.isDirectoryKey, .isSymbolicLinkKey])
            guard values.isSymbolicLink != true else {
                throw ActorGenerationError.sourceWriteFailure(
                    path: url.path,
                    reason: "Generated output must not contain symbolic links"
                )
            }
            guard values.isDirectory != true else {
                continue
            }
            let canonicalComponents = url
                .resolvingSymlinksInPath()
                .standardizedFileURL
                .pathComponents
            guard canonicalComponents.starts(with: canonicalOutputComponents),
                  canonicalComponents.count > canonicalOutputComponents.count
            else {
                throw ActorGenerationError.sourceWriteFailure(
                    path: url.path,
                    reason: "The generated output entry is outside its output directory"
                )
            }
            let relativePath = canonicalComponents
                .dropFirst(canonicalOutputComponents.count)
                .joined(separator: "/")
            if relativePath != manifestName {
                actualPaths.insert(relativePath)
            }
        }
        guard actualPaths == expectedPaths else {
            throw ActorGenerationError.sourceWriteFailure(
                path: outputDirectory.path,
                reason: "The generated output contains files not owned by its manifest; expected \(expectedPaths.sorted()), found \(actualPaths.sorted())"
            )
        }
        for (relativePath, expectedDigest) in expectedDigests {
            let url = try generatedURL(
                relativePath: relativePath,
                outputDirectory: outputDirectory
            )
            let contents: String
            do {
                contents = try String(contentsOf: url, encoding: .utf8)
            } catch {
                throw ActorGenerationError.sourceWriteFailure(
                    path: url.path,
                    reason: "The generated output cannot be read: \(error)"
                )
            }
            guard ActorStableHash.digest(contents) == expectedDigest else {
                throw ActorGenerationError.sourceWriteFailure(
                    path: url.path,
                    reason: "The generated output was modified after generation"
                )
            }
        }
    }

    private static func removeIfPresent(
        _ url: URL,
        fileManager: FileManager
    ) {
        guard fileManager.fileExists(atPath: url.path) else {
            return
        }
        do {
            try fileManager.removeItem(at: url)
        } catch {
            // Cleanup does not alter the committed generated source set.
        }
    }

    private static func generatedURL(
        relativePath: String,
        outputDirectory: URL
    ) throws -> URL {
        let components = relativePath.split(separator: "/", omittingEmptySubsequences: false)
        guard !relativePath.isEmpty,
              relativePath != manifestName,
              !relativePath.hasPrefix("/"),
              !components.contains(".."),
              !components.contains("."),
              !components.contains("")
        else {
            throw ActorGenerationError.sourceWriteFailure(
                path: relativePath,
                reason: "Generated paths must stay inside the output directory"
            )
        }
        return outputDirectory.appendingPathComponent(relativePath)
    }
}
