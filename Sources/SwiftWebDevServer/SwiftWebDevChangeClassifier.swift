import SwiftWebDevelopmentHooks
import SwiftWebPackageGeneration
import SwiftWebWasmBuild
import Foundation

package struct SwiftWebDevChangeClassifier: Sendable {
    private let appPackageDirectory: URL
    private let generatedPackage: SwiftWebGeneratedPackage

    package init(
        appPackageDirectory: URL,
        generatedPackage: SwiftWebGeneratedPackage
    ) {
        self.appPackageDirectory = appPackageDirectory.standardizedFileURL
        self.generatedPackage = generatedPackage
    }

    package func classify(_ changes: [SwiftWebDevFileChange]) -> SwiftWebDevChangePlan {
        var styleFiles: [URL] = []
        var clientRuntimes: [SwiftWebGeneratedWasmRuntime] = []
        var requiresServerRestart = false
        var reasons: [String] = []

        for change in changes {
            let path = change.path
            let url = change.url.standardizedFileURL

            if path == "Package.swift" || path.hasSuffix("/Package.swift") {
                requiresServerRestart = true
                reasons.append(path)
                continue
            }

            if isStyleFile(url) {
                styleFiles.append(url)
                continue
            }

            if url.pathExtension == "swift" {
                let classification: SwiftWebDevSwiftFileClassification
                do {
                    classification = try SwiftWebDevSwiftFileClassifier.classify(url: url)
                } catch {
                    requiresServerRestart = true
                    reasons.append(path)
                    continue
                }
                let runtimes = matchingClientRuntimes(for: url, classification: classification)
                clientRuntimes.append(contentsOf: runtimes)
                if runtimes.isEmpty || classification.hasServerRuntimeSurface {
                    requiresServerRestart = true
                    reasons.append(path)
                }
                continue
            }

            requiresServerRestart = true
            reasons.append(path)
        }

        return SwiftWebDevChangePlan(
            styleFiles: uniqueURLs(styleFiles),
            clientRuntimes: uniqueRuntimes(clientRuntimes),
            requiresServerRestart: requiresServerRestart,
            serverRestartReasons: reasons,
            changedPaths: changes.map(\.path)
        )
    }

    private func isStyleFile(_ url: URL) -> Bool {
        switch url.pathExtension {
        case "css":
            return true
        default:
            return false
        }
    }

    private func matchingClientRuntimes(
        for url: URL,
        classification: SwiftWebDevSwiftFileClassification
    ) -> [SwiftWebGeneratedWasmRuntime] {
        guard url.path.hasPrefix(appPackageDirectory.path) else {
            return []
        }
        guard !classification.clientComponentTypeNames.isEmpty else {
            return []
        }
        return generatedPackage.wasmRuntimes.filter { runtime in
            runtime.componentTypeNames.contains { componentTypeName in
                classification.clientComponentTypeNames.contains(componentTypeName)
            }
        }
    }

    private func uniqueURLs(_ urls: [URL]) -> [URL] {
        var seen = Set<String>()
        var output: [URL] = []
        for url in urls {
            let standardized = url.standardizedFileURL
            if seen.insert(standardized.path).inserted {
                output.append(standardized)
            }
        }
        return output
    }

    private func uniqueRuntimes(
        _ runtimes: [SwiftWebGeneratedWasmRuntime]
    ) -> [SwiftWebGeneratedWasmRuntime] {
        var seen = Set<String>()
        var output: [SwiftWebGeneratedWasmRuntime] = []
        for runtime in runtimes {
            if seen.insert(runtime.productName).inserted {
                output.append(runtime)
            }
        }
        return output
    }
}

package struct SwiftWebDevChangePlan: Sendable, Equatable {
    package let styleFiles: [URL]
    package let clientRuntimes: [SwiftWebGeneratedWasmRuntime]
    package let requiresServerRestart: Bool
    package let serverRestartReasons: [String]
    package let changedPaths: [String]

    package var isEmpty: Bool {
        styleFiles.isEmpty && clientRuntimes.isEmpty && !requiresServerRestart
    }
}
