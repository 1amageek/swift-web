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

    package static func isExcludedDirectory(named name: String) -> Bool {
        excludedDirectoryNames.contains(name)
    }

    package static func isWatchedFile(_ url: URL) -> Bool {
        let name = url.lastPathComponent
        // Package.resolved is an output of dependency resolution, not an
        // input: builds rewrite it, so reacting to it would make the dev
        // server respond to its own side effects. Its "resolved" extension is
        // outside the watched set today; the explicit check keeps that true
        // even if the extension list grows.
        if name == "Package.resolved" {
            return false
        }
        if name == "Package.swift" || name.hasSuffix(".swift") {
            return true
        }
        return watchedPathExtensions.contains(url.pathExtension)
    }
}
