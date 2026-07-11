import SwiftWebDevelopmentHooks
import SwiftWebPackageGeneration
import SwiftWebWasmBuild
import Foundation

/// Prepares the process environment shared by dev build invocations and
/// launched dev workers. The SwiftPM module cache and temporary directories
/// are pinned under the scratch directory so repeated builds stay warm and
/// isolated from the host defaults (docs/DevServerReconcilerDesign.md §5).
package struct SwiftWebDevProcessEnvironment: Sendable {
    package let configuration: SwiftWebDevRuntimeConfiguration

    package init(configuration: SwiftWebDevRuntimeConfiguration) {
        self.configuration = configuration
    }

    package func processEnvironment(
        toolchain: SwiftWebHostSwiftToolchain? = nil
    ) throws -> [String: String] {
        let moduleCacheDirectory = self.moduleCacheDirectory
        let temporaryDirectory = self.temporaryDirectory
        try FileManager.default.createDirectory(
            at: moduleCacheDirectory,
            withIntermediateDirectories: true
        )
        try FileManager.default.createDirectory(
            at: temporaryDirectory,
            withIntermediateDirectories: true
        )

        var environment = ProcessInfo.processInfo.environment
        environment["SWIFTPM_MODULECACHE_OVERRIDE"] = moduleCacheDirectory.path
        environment["CLANG_MODULE_CACHE_PATH"] = moduleCacheDirectory.path
        environment["TMPDIR"] = temporaryDirectory.path + "/"
        environment["TMP"] = temporaryDirectory.path
        environment["TEMP"] = temporaryDirectory.path
        if let toolchain {
            environment = toolchain.applying(to: environment)
        }
        return environment
    }

    package var moduleCacheDirectory: URL {
        if let scratchDirectory = configuration.scratchDirectory {
            return scratchDirectory
                .appendingPathComponent("swiftpm-module-cache", isDirectory: true)
                .standardizedFileURL
        }

        return configuration.packageDirectory
            .appendingPathComponent(".swiftweb", isDirectory: true)
            .appendingPathComponent("module-cache", isDirectory: true)
            .standardizedFileURL
    }

    package var temporaryDirectory: URL {
        if let scratchDirectory = configuration.scratchDirectory {
            return scratchDirectory
                .appendingPathComponent("tmp", isDirectory: true)
                .standardizedFileURL
        }

        return configuration.packageDirectory
            .appendingPathComponent(".swiftweb", isDirectory: true)
            .appendingPathComponent("tmp", isDirectory: true)
            .standardizedFileURL
    }

    package var wasmScratchDirectory: URL? {
        SwiftWebDevWasmScratchDirectory.resolve(from: configuration.scratchDirectory)
    }
}
