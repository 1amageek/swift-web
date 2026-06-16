import Foundation

struct SwiftWebDevChangeClassifier: Sendable {
    private let appPackageDirectory: URL
    private let generatedPackage: SwiftWebGeneratedPackage

    init(
        appPackageDirectory: URL,
        generatedPackage: SwiftWebGeneratedPackage
    ) {
        self.appPackageDirectory = appPackageDirectory.standardizedFileURL
        self.generatedPackage = generatedPackage
    }

    func classify(_ changes: [SwiftWebDevFileChange]) -> SwiftWebDevChangePlan {
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
                let runtime: SwiftWebGeneratedWasmRuntime?
                do {
                    runtime = try clientRuntime(for: url)
                } catch {
                    requiresServerRestart = true
                    reasons.append(path)
                    continue
                }
                if let runtime {
                    clientRuntimes.append(runtime)
                } else {
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

    private func clientRuntime(for url: URL) throws -> SwiftWebGeneratedWasmRuntime? {
        guard url.path.hasPrefix(appPackageDirectory.path) else {
            return nil
        }
        let source = try String(contentsOf: url, encoding: .utf8)
        return generatedPackage.wasmRuntimes.first { runtime in
            source.contains(runtime.componentTypeName)
                && source.contains("ClientComponent")
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

struct SwiftWebDevChangePlan: Sendable, Equatable {
    let styleFiles: [URL]
    let clientRuntimes: [SwiftWebGeneratedWasmRuntime]
    let requiresServerRestart: Bool
    let serverRestartReasons: [String]
    let changedPaths: [String]

    var isEmpty: Bool {
        styleFiles.isEmpty && clientRuntimes.isEmpty && !requiresServerRestart
    }
}
