import SwiftWebDevelopmentHooks
import SwiftWebWasmBuild
import Foundation

public enum SwiftWebGeneratedPackageMaterializerError: Error, Sendable, CustomStringConvertible {
    case packageManifestNotFound(URL)
    case packageNameNotFound(URL)
    case localDependencyNotFound(package: String, in: URL)
    case clientSourceDirectoryNotFound(URL)
    case swiftHTMLRuntimeSourcesNotFound([URL])
    case actorSystemRuntimeSourcesNotFound([URL])
    case legacyActorContractsUnsupported(
        profile: SwiftWebWasmRuntimeProfile,
        contracts: [String]
    )
    case javaScriptKitRuntimeSourcesNotFound([URL])
    case invalidPackageResolved(URL)
    case packageResolveFailed(package: URL, status: Int32, output: String)
    case materializationLockOpenFailed(URL, Int32)
    case materializationLockFailed(URL, Int32)
    case materializationRollbackFailed(original: String, rollback: String)
    case materializationRecoveryFailed(URL, String)
    case materializationCleanupFailed(URL, String)

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
        case .swiftHTMLRuntimeSourcesNotFound(let candidates):
            let paths = candidates.map(\.path).joined(separator: ", ")
            return "SwiftHTML runtime sources were not found. Checked: \(paths)"
        case .actorSystemRuntimeSourcesNotFound(let candidates):
            let paths = candidates.map(\.path).joined(separator: ", ")
            return "swift-actor-system runtime sources were not found. Checked: \(paths)"
        case .legacyActorContractsUnsupported(let profile, let contracts):
            return "Generated \(profile.rawValue) WASM runtimes require concrete actor bindings; legacy actor contracts were found: \(contracts.joined(separator: ", "))"
        case .javaScriptKitRuntimeSourcesNotFound(let candidates):
            let paths = candidates.map(\.path).joined(separator: ", ")
            return "JavaScriptKit runtime sources were not found. Checked: \(paths)"
        case .invalidPackageResolved(let file):
            return "Package.resolved is invalid at \(file.path)"
        case .packageResolveFailed(let package, let status, let output):
            return "swift package resolve failed in \(package.path) with status \(status): \(output)"
        case .materializationLockOpenFailed(let lockFile, let code):
            return "materialization lock could not be opened at \(lockFile.path): errno \(code)"
        case .materializationLockFailed(let lockFile, let code):
            return "materialization lock could not be acquired at \(lockFile.path): errno \(code)"
        case .materializationRollbackFailed(let original, let rollback):
            return "generated package rollback failed after \(original): \(rollback)"
        case .materializationRecoveryFailed(let journal, let reason):
            return "generated package recovery failed at \(journal.path): \(reason)"
        case .materializationCleanupFailed(let directory, let reason):
            return "generated package transaction cleanup failed at \(directory.path): \(reason)"
        }
    }
}
