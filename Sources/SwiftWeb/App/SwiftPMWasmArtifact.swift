import Foundation

public enum SwiftPMWasmArtifact {
    public static func location(
        anchorFile: String = #filePath,
        target: String,
        artifactName: String? = nil,
        configuration: String = "release",
        triple: String = "wasm32-unknown-wasip1"
    ) -> SwiftPMWasmArtifactLocation {
        SwiftPMWasmArtifactLocation(
            anchorFile: anchorFile,
            target: target,
            artifactName: artifactName,
            configuration: configuration,
            triple: triple
        )
    }

    public static func url(
        anchorFile: String = #filePath,
        target: String,
        artifactName: String? = nil,
        configuration: String = "release",
        triple: String = "wasm32-unknown-wasip1"
    ) throws -> URL {
        let packageRoot = try findPackageRoot(containing: URL(fileURLWithPath: anchorFile))
        let candidates = artifactNameCandidates(target: target, artifactName: artifactName)

        for outputDirectory in outputDirectories(for: packageRoot, triple: triple, configuration: configuration) {
            for candidate in candidates {
                let url = outputDirectory.appendingPathComponent("\(candidate).wasm")
                if FileManager.default.fileExists(atPath: url.path) {
                    return url
                }
            }
        }

        return outputDirectories(for: packageRoot, triple: triple, configuration: configuration)[0]
            .appendingPathComponent("\(candidates[0]).wasm")
    }

    private static func findPackageRoot(containing fileURL: URL) throws -> URL {
        var candidate = fileURL.deletingLastPathComponent()
        let fileManager = FileManager.default

        while candidate.path != "/" {
            let packageFile = candidate.appendingPathComponent("Package.swift")
            if fileManager.fileExists(atPath: packageFile.path) {
                return candidate
            }
            candidate.deleteLastPathComponent()
        }

        throw SwiftPMWasmArtifactError.packageRootNotFound(fileURL.path)
    }

    private static func artifactNameCandidates(target: String, artifactName: String?) -> [String] {
        var candidates: [String] = []

        if let artifactName {
            candidates.append(artifactName)
        }
        candidates.append(target)
        candidates.append(kebabCase(target))
        candidates.append(target.lowercased())

        var unique: [String] = []
        for candidate in candidates where !unique.contains(candidate) {
            unique.append(candidate)
        }
        return unique
    }

    private static func outputDirectories(
        for packageRoot: URL,
        triple: String,
        configuration: String
    ) -> [URL] {
        let roots = artifactSearchRoots(for: packageRoot)
        return roots.map {
            $0.appendingPathComponent(".build")
                .appendingPathComponent(triple)
                .appendingPathComponent(configuration)
                .standardizedFileURL
        }
    }

    private static func artifactSearchRoots(for packageRoot: URL) -> [URL] {
        var roots: [URL] = []
        var seen = Set<String>()

        func append(_ root: URL) {
            let standardizedRoot = root.standardizedFileURL
            if seen.insert(standardizedRoot.path).inserted {
                roots.append(standardizedRoot)
            }
        }

        append(packageRoot)
        append(packageRoot.appendingPathComponent(".swiftweb/generated", isDirectory: true))

        for dependencyRoot in localPackageDependencyRoots(for: packageRoot) {
            append(dependencyRoot)
        }

        return roots
    }

    private static func localPackageDependencyRoots(for packageRoot: URL) -> [URL] {
        let packageFile = packageRoot.appendingPathComponent("Package.swift")
        let manifest: String
        let regex: NSRegularExpression

        do {
            manifest = try String(contentsOf: packageFile, encoding: .utf8)
            regex = try NSRegularExpression(
                pattern: #"\.package\s*\(\s*path\s*:\s*"([^"]+)""#
            )
        } catch {
            return []
        }

        let range = NSRange(manifest.startIndex..<manifest.endIndex, in: manifest)
        return regex.matches(in: manifest, range: range).compactMap { match in
            guard match.numberOfRanges > 1,
                  let pathRange = Range(match.range(at: 1), in: manifest)
            else {
                return nil
            }

            let rawPath = String(manifest[pathRange])
            if rawPath.hasPrefix("/") {
                return URL(fileURLWithPath: rawPath).standardizedFileURL
            }
            return packageRoot
                .appendingPathComponent(rawPath, isDirectory: true)
                .standardizedFileURL
        }
    }

    private static func kebabCase(_ value: String) -> String {
        var output = ""
        for scalar in value.unicodeScalars {
            let character = Character(scalar)
            if CharacterSet.uppercaseLetters.contains(scalar) {
                if !output.isEmpty {
                    output.append("-")
                }
                output.append(String(character).lowercased())
            } else {
                output.append(String(character))
            }
        }
        return output
    }
}
