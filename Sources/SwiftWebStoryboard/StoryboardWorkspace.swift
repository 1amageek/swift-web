import Foundation

/// Resolves the on-disk locations a storyboard run depends on:
/// the default managed storyboard directory and the local `swift-web`
/// package that supplies the runtime sources.
struct StoryboardWorkspace {
    let packageDirectory: URL

    init(packageDirectory: URL) {
        self.packageDirectory = packageDirectory.standardizedFileURL
    }

    /// Default managed storyboard directory: `<package>/.swiftweb/storyboard`.
    var defaultStoryboardDirectory: URL {
        packageDirectory
            .appendingPathComponent(".swiftweb", isDirectory: true)
            .appendingPathComponent("storyboard", isDirectory: true)
            .standardizedFileURL
    }

    /// Locates the local `swift-web` package directory, either the package
    /// itself or one of its local path dependencies.
    func resolveSwiftWebPackageDirectory() throws -> URL {
        let packageName = try Self.packageName(in: packageDirectory)
        if packageName == "swift-web" {
            return packageDirectory
        }

        for root in try Self.localPackageRoots(for: packageDirectory) {
            if try Self.packageName(in: root) == "swift-web" {
                return root
            }
        }

        throw StoryboardError.swiftWebPackageNotFound(packageDirectory)
    }

    private static func packageName(in packageDirectory: URL) throws -> String {
        let packageFile = packageDirectory.appendingPathComponent("Package.swift")
        guard FileManager.default.fileExists(atPath: packageFile.path) else {
            throw StoryboardError.packageManifestNotFound(packageDirectory)
        }

        let manifest = try String(contentsOf: packageFile, encoding: .utf8)
        let regex = try NSRegularExpression(pattern: #"Package\s*\(\s*name\s*:\s*"([^"]+)""#)
        let range = NSRange(manifest.startIndex..<manifest.endIndex, in: manifest)
        guard let match = regex.firstMatch(in: manifest, range: range),
              match.numberOfRanges > 1,
              let nameRange = Range(match.range(at: 1), in: manifest)
        else {
            throw StoryboardError.packageNameNotFound(packageFile)
        }

        return String(manifest[nameRange])
    }

    private static func localPackageRoots(for packageDirectory: URL) throws -> [URL] {
        let packageFile = packageDirectory.appendingPathComponent("Package.swift")
        let manifest = try String(contentsOf: packageFile, encoding: .utf8)
        let regex = try NSRegularExpression(pattern: #"\.package\s*\(\s*path\s*:\s*"([^"]+)""#)
        let range = NSRange(manifest.startIndex..<manifest.endIndex, in: manifest)
        let matches = regex.matches(in: manifest, range: range)
        var roots: [URL] = []
        var seenPaths = Set<String>()

        for match in matches {
            guard match.numberOfRanges > 1,
                  let pathRange = Range(match.range(at: 1), in: manifest)
            else {
                continue
            }

            let rawPath = String(manifest[pathRange])
            let root = rawPath.hasPrefix("/")
                ? URL(fileURLWithPath: rawPath).standardizedFileURL
                : packageDirectory.appendingPathComponent(rawPath, isDirectory: true).standardizedFileURL
            let rootPackageFile = root.appendingPathComponent("Package.swift")
            guard FileManager.default.fileExists(atPath: rootPackageFile.path) else {
                continue
            }

            if seenPaths.insert(root.path).inserted {
                roots.append(root)
            }
        }

        return roots
    }
}
