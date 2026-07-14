import Foundation

/// The single definition of which directories and files the dev server
/// watches and fingerprints. The change watcher and the source fingerprint
/// scanner both consult this policy so they can never disagree about the
/// watched set (docs/DevServerReconcilerDesign.md §3, §7).
package enum SwiftWebDevWatchedFilePolicy {
    package static let excludedDirectoryNames: Set<String> = [
        ".build",
        ".git",
        ".swiftweb",
        ".swiftpm",
        "DerivedData",
    ]

    private static let watchedPathExtensions: Set<String> = [
        "css",
        "json",
        "html",
        "leaf",
    ]

    private static let sourcePathExtensions: Set<String> = [
        "swift",
        "c",
        "m",
        "mm",
        "cc",
        "cpp",
        "cxx",
        "h",
        "hh",
        "hpp",
        "modulemap",
        "metal",
    ]

    private static let buildInputDirectoryNames: Set<String> = [
        "Sources",
        "Plugins",
        "Resources",
        "Public",
    ]

    package static func isExcludedDirectory(named name: String) -> Bool {
        excludedDirectoryNames.contains(name)
    }

    package static func isWatchedFile(_ url: URL) -> Bool {
        let name = url.lastPathComponent
        if name == "Package.swift" || name == "Package.resolved" {
            return true
        }
        if url.pathComponents.contains(where: buildInputDirectoryNames.contains) {
            return true
        }
        let pathExtension = url.pathExtension.lowercased()
        return sourcePathExtensions.contains(pathExtension)
            || watchedPathExtensions.contains(pathExtension)
    }
}
