import Foundation

public enum SwiftWebPackageManifestInspector {
    public static func packageName(in packageDirectory: URL) throws -> String {
        let packageFile = packageDirectory.appendingPathComponent("Package.swift")
        guard FileManager.default.fileExists(atPath: packageFile.path) else {
            throw SwiftWebGeneratedPackageMaterializerError.packageManifestNotFound(packageDirectory)
        }

        let manifest = try String(contentsOf: packageFile, encoding: .utf8)
        let regex = try NSRegularExpression(pattern: #"Package\s*\(\s*name\s*:\s*"([^"]+)""#)
        let range = NSRange(manifest.startIndex..<manifest.endIndex, in: manifest)
        guard let match = regex.firstMatch(in: manifest, range: range),
              match.numberOfRanges > 1,
              let nameRange = Range(match.range(at: 1), in: manifest)
        else {
            throw SwiftWebGeneratedPackageMaterializerError.packageNameNotFound(packageFile)
        }

        return String(manifest[nameRange])
    }

    public static func packageRoot(
        named packageName: String,
        from packageDirectory: URL
    ) throws -> URL {
        if try self.packageName(in: packageDirectory) == packageName {
            return packageDirectory.standardizedFileURL
        }

        return try localDependencyRoot(named: packageName, in: packageDirectory)
    }

    public static func localDependencyRoot(
        named dependencyPackageName: String,
        in packageDirectory: URL
    ) throws -> URL {
        if let root = try optionalLocalDependencyRoot(named: dependencyPackageName, in: packageDirectory) {
            return root
        }

        throw SwiftWebGeneratedPackageMaterializerError.localDependencyNotFound(
            package: dependencyPackageName,
            in: packageDirectory
        )
    }

    public static func optionalLocalDependencyRoot(
        named dependencyPackageName: String,
        in packageDirectory: URL
    ) throws -> URL? {
        let roots = try SwiftWebDevLocalPackageDependencyResolver.localPackageRoots(
            for: packageDirectory
        )

        for root in roots {
            let name = try packageName(in: root)
            if name == dependencyPackageName {
                return root
            }
        }

        return nil
    }
}
