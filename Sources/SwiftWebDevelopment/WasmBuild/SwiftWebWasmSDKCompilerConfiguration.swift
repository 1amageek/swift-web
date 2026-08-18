import Foundation

public struct SwiftWebWasmSDKCompilerConfiguration: Sendable {
    public static let targetTriple = "wasm32-unknown-wasip1"

    public let sdkRootURL: URL
    public let swiftResourcesURL: URL
    public let additionalCompilerArguments: [String]

    public var compilerArguments: [String] {
        [
            "-target", Self.targetTriple,
            "-sdk", sdkRootURL.path,
            "-resource-dir", swiftResourcesURL.path,
        ] + additionalCompilerArguments
    }

    public static func resolve(
        sdkName: String,
        homeDirectory: URL? = nil,
        fileManager: FileManager = .default
    ) throws -> SwiftWebWasmSDKCompilerConfiguration {
        let baseSDKName = sdkName.hasSuffix("-embedded")
            ? String(sdkName.dropLast("-embedded".count))
            : sdkName
        let variantDirectory = (homeDirectory ?? fileManager.homeDirectoryForCurrentUser)
            .appendingPathComponent("Library", isDirectory: true)
            .appendingPathComponent("org.swift.swiftpm", isDirectory: true)
            .appendingPathComponent("swift-sdks", isDirectory: true)
            .appendingPathComponent("\(baseSDKName).artifactbundle", isDirectory: true)
            .appendingPathComponent(baseSDKName, isDirectory: true)
            .appendingPathComponent(Self.targetTriple, isDirectory: true)
            .standardizedFileURL
        let specificationName = sdkName.hasSuffix("-embedded")
            ? "embedded-swift-sdk.json"
            : "swift-sdk.json"
        let specificationURL = variantDirectory.appendingPathComponent(specificationName)
        guard fileManager.fileExists(atPath: specificationURL.path) else {
            throw SwiftWebWasmBuildError.swiftSDKConfigurationNotFound(
                sdkName: sdkName,
                searched: [specificationURL.path]
            )
        }

        let specification: SDKSpecification
        do {
            specification = try JSONDecoder().decode(
                SDKSpecification.self,
                from: Data(contentsOf: specificationURL)
            )
        } catch {
            throw SwiftWebWasmBuildError.invalidSwiftSDKConfiguration(
                sdkName: sdkName,
                path: specificationURL.path,
                reason: String(describing: error)
            )
        }
        guard let target = specification.targetTriples[Self.targetTriple] else {
            throw SwiftWebWasmBuildError.invalidSwiftSDKConfiguration(
                sdkName: sdkName,
                path: specificationURL.path,
                reason: "missing target triple \(Self.targetTriple)"
            )
        }

        let sdkRootURL = variantDirectory
            .appendingPathComponent(target.sdkRootPath, isDirectory: true)
            .standardizedFileURL
        let swiftResourcesURL = variantDirectory
            .appendingPathComponent(target.swiftResourcesPath, isDirectory: true)
            .standardizedFileURL
        guard fileManager.fileExists(atPath: sdkRootURL.path),
              fileManager.fileExists(atPath: swiftResourcesURL.path)
        else {
            throw SwiftWebWasmBuildError.swiftSDKConfigurationNotFound(
                sdkName: sdkName,
                searched: [sdkRootURL.path, swiftResourcesURL.path]
            )
        }

        var additionalCompilerArguments: [String] = []
        for relativeToolsetPath in target.toolsetPaths {
            let toolsetURL = variantDirectory
                .appendingPathComponent(relativeToolsetPath)
                .standardizedFileURL
            let toolset: ToolsetSpecification
            do {
                toolset = try JSONDecoder().decode(
                    ToolsetSpecification.self,
                    from: Data(contentsOf: toolsetURL)
                )
            } catch {
                throw SwiftWebWasmBuildError.invalidSwiftSDKConfiguration(
                    sdkName: sdkName,
                    path: toolsetURL.path,
                    reason: String(describing: error)
                )
            }
            additionalCompilerArguments.append(
                contentsOf: toolset.swiftCompiler?.extraCLIOptions ?? []
            )
        }

        return SwiftWebWasmSDKCompilerConfiguration(
            sdkRootURL: sdkRootURL,
            swiftResourcesURL: swiftResourcesURL,
            additionalCompilerArguments: additionalCompilerArguments
        )
    }
}

private struct SDKSpecification: Decodable {
    struct Target: Decodable {
        let sdkRootPath: String
        let swiftResourcesPath: String
        let toolsetPaths: [String]
    }

    let targetTriples: [String: Target]
}

private struct ToolsetSpecification: Decodable {
    struct SwiftCompiler: Decodable {
        let extraCLIOptions: [String]
    }

    let swiftCompiler: SwiftCompiler?
}
