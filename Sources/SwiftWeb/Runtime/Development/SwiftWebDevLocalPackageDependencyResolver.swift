import Foundation

enum SwiftWebDevLocalPackageDependencyResolver {
    static func localPackageRoots(for packageDirectory: URL) throws -> [URL] {
        let packageFile = packageDirectory.appendingPathComponent("Package.swift")
        let manifest = try String(contentsOf: packageFile, encoding: .utf8)
        let regex = try NSRegularExpression(
            pattern: #"\.package\s*\(\s*path\s*:\s*"([^"]+)""#
        )
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
            let root: URL
            if rawPath.hasPrefix("/") {
                root = URL(fileURLWithPath: rawPath).standardizedFileURL
            } else {
                root = packageDirectory
                    .appendingPathComponent(rawPath, isDirectory: true)
                    .standardizedFileURL
            }
            let packageFile = root.appendingPathComponent("Package.swift")
            guard FileManager.default.fileExists(atPath: packageFile.path) else {
                continue
            }

            if seenPaths.insert(root.path).inserted {
                roots.append(root)
            }
        }

        return roots
    }
}
