import Foundation
import SwiftWebDevelopment

/// Errors surfaced while generating or running a SwiftWebUI storyboard.
///
/// Each case carries a stable exit code so a host CLI can map it onto a
/// process exit status without re-deriving the failure semantics.
public enum StoryboardError: Error, Sendable, CustomStringConvertible {
    case storyboardDirectoryNotManaged(URL)
    case packageManifestNotFound(URL)
    case packageNameNotFound(URL)
    case swiftWebPackageNotFound(URL)
    case runtime(SwiftWebDevRuntimeError)

    public var description: String {
        switch self {
        case .storyboardDirectoryNotManaged(let directory):
            return "storyboard directory already exists and is not managed by swift-web: \(directory.path)"
        case .packageManifestNotFound(let packageDirectory):
            return "Package.swift was not found in \(packageDirectory.path)"
        case .packageNameNotFound(let packageFile):
            return "package name was not found in \(packageFile.path)"
        case .swiftWebPackageNotFound(let packageDirectory):
            return "local dependency swift-web was not found in \(packageDirectory.path)"
        case .runtime(let error):
            return error.description
        }
    }

    public var exitCode: Int {
        switch self {
        case .storyboardDirectoryNotManaged:
            return 73
        case .packageManifestNotFound, .packageNameNotFound, .swiftWebPackageNotFound:
            return 66
        case .runtime(let error):
            return error.exitCode
        }
    }
}
