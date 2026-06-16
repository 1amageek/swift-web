import Foundation

public enum SwiftWebGeneratedPackageMaterializerError: Error, Sendable, CustomStringConvertible {
    case packageManifestNotFound(URL)
    case packageNameNotFound(URL)
    case localDependencyNotFound(package: String, in: URL)
    case clientSourceDirectoryNotFound(URL)
    case materializationLockOpenFailed(URL, Int32)
    case materializationLockFailed(URL, Int32)

    public var description: String {
        switch self {
        case .packageManifestNotFound(let directory):
            return "Package.swift was not found in \(directory.path)"
        case .packageNameNotFound(let packageFile):
            return "package name was not found in \(packageFile.path)"
        case .localDependencyNotFound(let package, let directory):
            return "local dependency \(package) was not found in \(directory.path)"
        case .clientSourceDirectoryNotFound(let directory):
            return "client source directory was not found at \(directory.path)"
        case .materializationLockOpenFailed(let lockFile, let code):
            return "materialization lock could not be opened at \(lockFile.path): errno \(code)"
        case .materializationLockFailed(let lockFile, let code):
            return "materialization lock could not be acquired at \(lockFile.path): errno \(code)"
        }
    }
}
