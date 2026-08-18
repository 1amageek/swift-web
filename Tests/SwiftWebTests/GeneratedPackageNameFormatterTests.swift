@testable import SwiftWebPackageGeneration
import Foundation
import Testing

@Suite
struct GeneratedPackageNameFormatterTests {
    @Test
    func relativePathSurvivesCanonicalizationOfTemporaryDirectoryAliases() throws {
        let temporaryRoot = URL(fileURLWithPath: "/tmp", isDirectory: true)
            .appendingPathComponent("SwiftWebGeneratedPathTests-\(UUID().uuidString)")
        let baseDirectory = temporaryRoot
            .appendingPathComponent("generated/server", isDirectory: true)
        defer {
            do {
                try FileManager.default.removeItem(at: temporaryRoot)
            } catch {
                Issue.record("Failed to remove temporary directory: \(error)")
            }
        }
        try FileManager.default.createDirectory(
            at: temporaryRoot,
            withIntermediateDirectories: true
        )
        let targetDirectory = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()

        let relativePath = GeneratedPackageNameFormatter.relativePath(
            from: baseDirectory,
            to: targetDirectory
        )
        try FileManager.default.createDirectory(
            at: baseDirectory,
            withIntermediateDirectories: true
        )
        let canonicalBase = GeneratedPackageNameFormatter.canonicalFileURL(baseDirectory)
        let resolvedTarget = canonicalBase
            .appendingPathComponent(relativePath)
            .standardizedFileURL

        #expect(
            resolvedTarget.path
                == GeneratedPackageNameFormatter.canonicalFileURL(targetDirectory).path
        )
    }
}
