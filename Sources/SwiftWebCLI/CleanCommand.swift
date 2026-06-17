import Foundation
import SwiftWebDevelopment

struct CleanCommand {
    let packageDirectory: URL
    let cleansSwiftPMBuild: Bool
    let cleansStoryboard: Bool

    static func parse(_ parser: ArgumentParser) throws -> CleanCommand {
        var parser = parser
        var packageDirectory = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
        var cleansSwiftPMBuild = false
        var cleansStoryboard = false

        while let option = parser.next() {
            switch option {
            case "--package-path":
                packageDirectory = URL(fileURLWithPath: try parser.requireValue(after: option))
            case "--swiftpm":
                cleansSwiftPMBuild = true
            case "--storyboard":
                cleansStoryboard = true
            case "--all":
                cleansSwiftPMBuild = true
                cleansStoryboard = true
            default:
                throw CLIError(message: "unknown option: \(option)", exitCode: 64)
            }
        }

        return CleanCommand(
            packageDirectory: packageDirectory.standardizedFileURL,
            cleansSwiftPMBuild: cleansSwiftPMBuild,
            cleansStoryboard: cleansStoryboard
        )
    }

    func run() throws {
        let cleaner = SwiftWebDevBuildArtifactCleaner()
        var report = try cleaner.cleanGeneratedArtifacts(in: packageDirectory)

        if cleansStoryboard {
            report.merge(try cleaner.cleanStoryboard(in: packageDirectory))
        }
        if cleansSwiftPMBuild {
            report.merge(try cleaner.cleanSwiftPMBuild(in: packageDirectory))
        }

        if report.isEmpty {
            print("No SwiftWeb build artifacts found.")
            return
        }

        print("Removed SwiftWeb build artifacts:")
        for path in report.removedPaths.sorted() {
            print("- \(path)")
        }
    }
}
