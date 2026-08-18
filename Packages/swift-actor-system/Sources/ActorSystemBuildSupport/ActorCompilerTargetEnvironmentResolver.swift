import ActorSystemGeneration
import Foundation

public enum ActorCompilerTargetEnvironmentResolver {
    public static func resolve(
        swiftCompiler: URL,
        compilerArguments: [String] = [],
        availableModules: Set<String>,
        additionalCustomConditions: Set<String> = [],
        additionalFeatures: Set<String> = [],
        featureProbeCandidates: Set<String> = [],
        attributes: Set<String>? = nil,
        atomicBitWidthCandidates: [Int] = [8, 16, 32, 64, 128]
    ) throws -> ActorGenerationTargetEnvironment {
        let arguments = ["-print-target-info"] + compilerArguments
        let process = Process()
        let standardOutput = Pipe()
        let standardError = Pipe()
        process.executableURL = swiftCompiler
        process.arguments = arguments
        process.standardOutput = standardOutput
        process.standardError = standardError
        try process.run()
        let data = standardOutput.fileHandleForReading.readDataToEndOfFile()
        let errorData = standardError.fileHandleForReading.readDataToEndOfFile()
        process.waitUntilExit()
        guard process.terminationStatus == 0 else {
            throw ActorGenerationError.toolchainFailure(
                command: ([swiftCompiler.path] + arguments).joined(separator: " "),
                status: process.terminationStatus,
                output: [data, errorData]
                    .map { String(decoding: $0, as: UTF8.self) }
                    .filter { !$0.isEmpty }
                    .joined(separator: "\n")
            )
        }
        let targetInfo: TargetInfo
        do {
            targetInfo = try JSONDecoder().decode(TargetInfo.self, from: data)
        } catch {
            throw ActorGenerationError.toolchainFailure(
                command: ([swiftCompiler.path] + arguments).joined(separator: " "),
                status: process.terminationStatus,
                output: "Invalid -print-target-info response: \(error)"
            )
        }
        let target = try ParsedTargetTriple(targetInfo.target.unversionedTriple)
        let flags = CompilerConditionFlags(compilerArguments)
        let atomicBitWidths = try probeAtomicBitWidths(
            swiftCompiler: swiftCompiler,
            compilerArguments: compilerArguments,
            candidates: atomicBitWidthCandidates
        )
        let probedFeatures = try probeFeatures(
            swiftCompiler: swiftCompiler,
            compilerArguments: compilerArguments,
            candidates: featureProbeCandidates
        )
        return try ActorGenerationTargetEnvironment(
            availableModules: availableModules,
            customConditions: flags.customConditions.union(additionalCustomConditions),
            features: flags.features.union(additionalFeatures).union(probedFeatures),
            attributes: attributes,
            operatingSystem: target.operatingSystem,
            architecture: target.architecture,
            targetEnvironments: target.targetEnvironment.map { Set([$0]) } ?? [],
            runtimes: target.runtimes(
                disableObjectiveCInterop: flags.disablesObjectiveCInterop
            ),
            objectFormat: target.objectFormat,
            pointerBitWidth: target.pointerBitWidth,
            atomicBitWidths: atomicBitWidths,
            endianness: target.endianness,
            languageVersion: flags.languageVersion ?? [6],
            compilerVersion: compilerVersion(from: targetInfo.compilerVersion)
        )
    }

    private static func compilerVersion(from description: String) -> [Int] {
        let components = description.split(whereSeparator: { $0 == " " || $0 == "(" })
        guard let versionIndex = components.firstIndex(of: "version"),
              components.indices.contains(versionIndex + 1)
        else {
            return [6]
        }
        let parsed = components[versionIndex + 1]
            .split(separator: ".")
            .compactMap { component -> Int? in
                Int(component.prefix(while: { $0.isNumber }))
            }
        return parsed.isEmpty ? [6] : parsed
    }

    private static func probeAtomicBitWidths(
        swiftCompiler: URL,
        compilerArguments: [String],
        candidates: [Int]
    ) throws -> [Int] {
        let validatedCandidates = Array(Set(candidates)).sorted()
        guard validatedCandidates.allSatisfy({ $0 > 0 && $0.isMultiple(of: 8) }) else {
            throw ActorGenerationError.invalidTargetEnvironment(
                reason: "atomic width probe candidates must be positive byte multiples"
            )
        }
        let temporaryDirectory = FileManager.default.temporaryDirectory
            .appendingPathComponent(
                "actor-target-environment-\(UUID().uuidString)",
                isDirectory: true
            )
        try FileManager.default.createDirectory(
            at: temporaryDirectory,
            withIntermediateDirectories: true
        )
        defer {
            do {
                try FileManager.default.removeItem(at: temporaryDirectory)
            } catch {
                // Probe cleanup does not change the compiler's target result.
            }
        }
        let sourceURL = temporaryDirectory.appendingPathComponent("AtomicWidths.swift")
        let source = validatedCandidates.map { width in
            """
            #if _hasAtomicBitWidth(_\(width))
            let __actorSystemAtomicWidth\(width) = \(width)
            #endif
            """
        }.joined(separator: "\n")
        try source.write(to: sourceURL, atomically: true, encoding: .utf8)
        let arguments = compilerArguments + ["-typecheck", "-dump-ast", sourceURL.path]
        let process = Process()
        let standardOutput = Pipe()
        let standardError = Pipe()
        process.executableURL = swiftCompiler
        process.arguments = arguments
        process.standardOutput = standardOutput
        process.standardError = standardError
        try process.run()
        let data = standardOutput.fileHandleForReading.readDataToEndOfFile()
        let errorData = standardError.fileHandleForReading.readDataToEndOfFile()
        process.waitUntilExit()
        let description = String(decoding: data, as: UTF8.self)
        let diagnostics = String(decoding: errorData, as: UTF8.self)
        guard process.terminationStatus == 0 else {
            throw ActorGenerationError.toolchainFailure(
                command: ([swiftCompiler.path] + arguments).joined(separator: " "),
                status: process.terminationStatus,
                output: [description, diagnostics]
                    .filter { !$0.isEmpty }
                    .joined(separator: "\n")
            )
        }
        return validatedCandidates.filter {
            description.contains("__actorSystemAtomicWidth\($0)")
        }
    }

    private static func probeFeatures(
        swiftCompiler: URL,
        compilerArguments: [String],
        candidates: Set<String>
    ) throws -> Set<String> {
        guard candidates.allSatisfy({ candidate in
            !candidate.isEmpty && candidate.allSatisfy {
                $0.isLetter || $0.isNumber || $0 == "_"
            }
        }) else {
            throw ActorGenerationError.invalidTargetEnvironment(
                reason: "feature probe candidates must be Swift identifiers"
            )
        }
        guard !candidates.isEmpty else {
            return []
        }
        let temporaryDirectory = FileManager.default.temporaryDirectory
            .appendingPathComponent(
                "actor-target-features-\(UUID().uuidString)",
                isDirectory: true
            )
        try FileManager.default.createDirectory(
            at: temporaryDirectory,
            withIntermediateDirectories: true
        )
        defer {
            do {
                try FileManager.default.removeItem(at: temporaryDirectory)
            } catch {
                // Probe cleanup does not change the compiler's target result.
            }
        }
        let sourceURL = temporaryDirectory.appendingPathComponent("Features.swift")
        let source = candidates.sorted().map { feature in
            """
            #if hasFeature(\(feature))
            let __actorSystemFeature_\(feature) = true
            #endif
            """
        }.joined(separator: "\n")
        try source.write(to: sourceURL, atomically: true, encoding: .utf8)
        let arguments = compilerArguments + ["-typecheck", "-dump-ast", sourceURL.path]
        let process = Process()
        let standardOutput = Pipe()
        let standardError = Pipe()
        process.executableURL = swiftCompiler
        process.arguments = arguments
        process.standardOutput = standardOutput
        process.standardError = standardError
        try process.run()
        let data = standardOutput.fileHandleForReading.readDataToEndOfFile()
        let errorData = standardError.fileHandleForReading.readDataToEndOfFile()
        process.waitUntilExit()
        let description = String(decoding: data, as: UTF8.self)
        let diagnostics = String(decoding: errorData, as: UTF8.self)
        guard process.terminationStatus == 0 else {
            throw ActorGenerationError.toolchainFailure(
                command: ([swiftCompiler.path] + arguments).joined(separator: " "),
                status: process.terminationStatus,
                output: [description, diagnostics]
                    .filter { !$0.isEmpty }
                    .joined(separator: "\n")
            )
        }
        return Set(candidates.filter {
            description.contains("__actorSystemFeature_\($0)")
        })
    }
}

private struct TargetInfo: Decodable {
    struct Target: Decodable {
        let unversionedTriple: String
    }

    let compilerVersion: String
    let target: Target
}

private struct CompilerConditionFlags {
    var customConditions = Set<String>()
    var features = Set<String>()
    var languageVersion: [Int]?
    var disablesObjectiveCInterop = false

    init(_ arguments: [String]) {
        var index = 0
        while index < arguments.count {
            let argument = arguments[index]
            switch argument {
            case "-D":
                if arguments.indices.contains(index + 1) {
                    customConditions.insert(arguments[index + 1])
                    index += 1
                }
            case let value where value.hasPrefix("-D") && value.count > 2:
                customConditions.insert(String(value.dropFirst(2)))
            case "-enable-upcoming-feature", "-enable-experimental-feature":
                if arguments.indices.contains(index + 1) {
                    features.insert(arguments[index + 1])
                    index += 1
                }
            case "-swift-version":
                if arguments.indices.contains(index + 1) {
                    let components = arguments[index + 1]
                        .split(separator: ".")
                        .compactMap { Int($0) }
                    languageVersion = components.isEmpty ? nil : components
                    index += 1
                }
            case "-disable-objc-interop":
                disablesObjectiveCInterop = true
            default:
                break
            }
            index += 1
        }
    }
}

struct ParsedTargetTriple {
    let architecture: String
    let vendor: String
    let operatingSystem: String
    let targetEnvironment: String?
    let pointerBitWidth: Int
    let endianness: ActorTargetEndianness

    init(_ triple: String) throws {
        let components = triple.split(separator: "-").map(String.init)
        guard components.count >= 3 else {
            throw ActorGenerationError.schemaConflict(
                reason: "Compiler returned an unsupported target triple \(triple)"
            )
        }
        let parsedArchitecture = Self.architectureName(components[0])
        architecture = parsedArchitecture
        vendor = components[1]
        operatingSystem = try Self.operatingSystemName(components[2], triple: triple)
        targetEnvironment = components.dropFirst(3)
            .compactMap(Self.environmentName)
            .first
        switch parsedArchitecture {
        case "arm", "i386", "wasm32", "riscv32", "mips", "mipsel", "powerpc":
            pointerBitWidth = 32
        case "arm64", "x86_64", "wasm64", "riscv64", "s390x", "powerpc64",
             "powerpc64le":
            pointerBitWidth = 64
        default:
            throw ActorGenerationError.invalidTargetEnvironment(
                reason: "Compiler returned an unsupported target architecture \(parsedArchitecture) in \(triple)"
            )
        }
        switch parsedArchitecture {
        case "s390x", "powerpc", "powerpc64":
            endianness = .big
        case "arm", "arm64", "i386", "x86_64", "wasm32", "wasm64", "riscv32",
             "riscv64", "mipsel", "powerpc64le":
            endianness = .little
        case "mips":
            endianness = .big
        default:
            throw ActorGenerationError.invalidTargetEnvironment(
                reason: "Compiler target endianness is unknown for \(parsedArchitecture)"
            )
        }
    }

    var objectFormat: String {
        if architecture.hasPrefix("wasm") { return "wasm" }
        if vendor == "apple" { return "macho" }
        if operatingSystem == "Windows" { return "coff" }
        return "elf"
    }

    func runtimes(disableObjectiveCInterop: Bool) -> Set<String> {
        vendor == "apple" && !disableObjectiveCInterop ? ["_ObjC"] : ["_Native"]
    }

    private static func architectureName(_ value: String) -> String {
        let lowercased = value.lowercased()
        if lowercased.hasPrefix("thumbv7") || lowercased.hasPrefix("armv7") {
            return "arm"
        }
        if lowercased == "arm64e" {
            return "arm64"
        }
        return switch lowercased {
        case "aarch64": "arm64"
        case "amd64": "x86_64"
        case "i486", "i586", "i686": "i386"
        case "powerpc64le": "powerpc64le"
        default: lowercased
        }
    }

    private static func operatingSystemName(
        _ value: String,
        triple: String
    ) throws -> String {
        let name = value.prefix { !$0.isNumber }
        switch name.lowercased() {
        case "macosx", "darwin": return "macOS"
        case "ios": return "iOS"
        case "tvos": return "tvOS"
        case "watchos": return "watchOS"
        case "xros", "visionos": return "visionOS"
        case "linux": return "Linux"
        case "windows": return "Windows"
        case "android": return "Android"
        case "freebsd": return "FreeBSD"
        case "openbsd": return "OpenBSD"
        case "wasi", "wasip", "wasip1", "wasip2": return "WASI"
        case "none": return "none"
        default:
            throw ActorGenerationError.schemaConflict(
                reason: "Compiler returned an unsupported target OS in \(triple)"
            )
        }
    }

    private static func environmentName(_ value: String) -> String? {
        switch value.lowercased() {
        case "simulator": "simulator"
        case "macabi": "macCatalyst"
        case "eabi", "eabihf": "freestanding"
        default: nil
        }
    }
}
