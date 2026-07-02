import SwiftWebDevelopmentHooks
import SwiftWebPackageGeneration
import CryptoKit
import Foundation

package struct SwiftWebWasmBuildInputHasher: Sendable {
    package static func hash(
        runtime: SwiftWebGeneratedWasmRuntime,
        sdkName: String,
        swiftExecutablePath: String,
        artifactProcessingSignature: String = ""
    ) throws -> String {
        var hasher = SHA256()
        update(&hasher, with: "sdk:\(sdkName)\n")
        update(&hasher, with: "swift:\(swiftExecutablePath)\n")
        update(&hasher, with: "artifact-processing:\(artifactProcessingSignature)\n")
        update(&hasher, with: "target:\(runtime.targetName)\n")
        update(&hasher, with: "product:\(runtime.productName)\n")
        update(&hasher, with: "bundle:\(runtime.bundleID.rawValue)\n")
        update(&hasher, with: "components:\(runtime.componentTypeNames.joined(separator: ","))\n")
        update(&hasher, with: "link-mode:\(runtime.linkMode.rawValue)\n")

        for file in try inputFiles(in: runtime.packageDirectory) {
            let relativePath = file.path
                .replacingOccurrences(of: runtime.packageDirectory.path + "/", with: "")
            update(&hasher, with: "file:\(relativePath)\n")
            update(&hasher, with: try Data(contentsOf: file))
            update(&hasher, with: "\n")
        }

        return hasher.finalize().map { String(format: "%02x", $0) }.joined()
    }

    private static func inputFiles(in packageDirectory: URL) throws -> [URL] {
        var files: [URL] = []
        let packageSwift = packageDirectory.appendingPathComponent("Package.swift")
        if FileManager.default.fileExists(atPath: packageSwift.path) {
            files.append(packageSwift)
        }
        let packageResolved = packageDirectory.appendingPathComponent("Package.resolved")
        if FileManager.default.fileExists(atPath: packageResolved.path) {
            files.append(packageResolved)
        }
        let sourcesDirectory = packageDirectory.appendingPathComponent("Sources", isDirectory: true)
        if FileManager.default.fileExists(atPath: sourcesDirectory.path) {
            files.append(contentsOf: try sourceFiles(in: sourcesDirectory))
        }
        return files.sorted { left, right in
            left.path < right.path
        }
    }

    private static func sourceFiles(in directory: URL) throws -> [URL] {
        let children = try FileManager.default.contentsOfDirectory(
            at: directory,
            includingPropertiesForKeys: [.isDirectoryKey],
            options: [.skipsHiddenFiles]
        )

        var files: [URL] = []
        for child in children {
            let values = try child.resourceValues(forKeys: [.isDirectoryKey])
            if values.isDirectory == true {
                files.append(contentsOf: try sourceFiles(in: child))
            } else if isHashedSourceFile(child) {
                files.append(child)
            }
        }
        return files
    }

    private static func isHashedSourceFile(_ url: URL) -> Bool {
        switch url.pathExtension.lowercased() {
        case "swift", "c", "cc", "cpp", "cxx", "h", "hh", "hpp", "modulemap":
            true
        default:
            false
        }
    }

    private static func update(_ hasher: inout SHA256, with string: String) {
        hasher.update(data: Data(string.utf8))
    }

    private static func update(_ hasher: inout SHA256, with data: Data) {
        hasher.update(data: data)
    }
}
