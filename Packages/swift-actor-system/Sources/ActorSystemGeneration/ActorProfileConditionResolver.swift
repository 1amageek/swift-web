import SwiftIfConfig
import SwiftSyntax

public enum ActorTargetEndianness: String, Sendable {
    case little
    case big
}

/// The compiler and target capabilities used to evaluate conditional source.
///
/// This value is intentionally independent of an actor generation profile. The
/// integration which owns the build graph must provide the modules, flags, and
/// target selected by the authoritative compiler invocation.
public struct ActorGenerationTargetEnvironment: Sendable {
    public let availableModules: Set<String>
    public let customConditions: Set<String>
    public let features: Set<String>
    public let attributes: Set<String>?
    public let operatingSystem: String
    public let architecture: String
    public let targetEnvironments: Set<String>
    public let runtimes: Set<String>
    public let pointerAuthentications: Set<String>?
    public let objectFormat: String
    public let pointerBitWidth: Int
    public let atomicBitWidths: [Int]
    public let endianness: ActorTargetEndianness
    public let languageVersion: [Int]
    public let compilerVersion: [Int]

    public init(
        availableModules: Set<String>,
        customConditions: Set<String> = [],
        features: Set<String> = [],
        attributes: Set<String>? = nil,
        operatingSystem: String,
        architecture: String,
        targetEnvironments: Set<String> = [],
        runtimes: Set<String> = ["_Native"],
        pointerAuthentications: Set<String>? = nil,
        objectFormat: String,
        pointerBitWidth: Int,
        atomicBitWidths: [Int] = [8, 16, 32, 64],
        endianness: ActorTargetEndianness = .little,
        languageVersion: [Int],
        compilerVersion: [Int]
    ) throws {
        guard !operatingSystem.isEmpty else {
            throw ActorGenerationError.invalidTargetEnvironment(
                reason: "operatingSystem must not be empty"
            )
        }
        guard !architecture.isEmpty else {
            throw ActorGenerationError.invalidTargetEnvironment(
                reason: "architecture must not be empty"
            )
        }
        guard ["macho", "elf", "coff", "wasm"].contains(objectFormat.lowercased()) else {
            throw ActorGenerationError.invalidTargetEnvironment(
                reason: "unsupported object format \(objectFormat)"
            )
        }
        guard pointerBitWidth > 0, pointerBitWidth.isMultiple(of: 8) else {
            throw ActorGenerationError.invalidTargetEnvironment(
                reason: "pointerBitWidth must be a positive byte multiple"
            )
        }
        guard !atomicBitWidths.contains(where: { $0 <= 0 || !$0.isMultiple(of: 8) }) else {
            throw ActorGenerationError.invalidTargetEnvironment(
                reason: "atomic bit widths must be positive byte multiples"
            )
        }
        guard !languageVersion.isEmpty, languageVersion.allSatisfy({ $0 >= 0 }) else {
            throw ActorGenerationError.invalidTargetEnvironment(
                reason: "languageVersion must contain nonnegative components"
            )
        }
        guard !compilerVersion.isEmpty, compilerVersion.allSatisfy({ $0 >= 0 }) else {
            throw ActorGenerationError.invalidTargetEnvironment(
                reason: "compilerVersion must contain nonnegative components"
            )
        }
        self.availableModules = availableModules
        self.customConditions = customConditions
        self.features = features
        self.attributes = attributes
        self.operatingSystem = operatingSystem
        self.architecture = architecture
        self.targetEnvironments = targetEnvironments
        self.runtimes = runtimes
        self.pointerAuthentications = pointerAuthentications
        self.objectFormat = objectFormat
        self.pointerBitWidth = pointerBitWidth
        self.atomicBitWidths = atomicBitWidths
        self.endianness = endianness
        self.languageVersion = languageVersion
        self.compilerVersion = compilerVersion
    }

    public func addingAvailableModules(
        _ modules: Set<String>
    ) throws -> ActorGenerationTargetEnvironment {
        try ActorGenerationTargetEnvironment(
            availableModules: availableModules.union(modules),
            customConditions: customConditions,
            features: features,
            attributes: attributes,
            operatingSystem: operatingSystem,
            architecture: architecture,
            targetEnvironments: targetEnvironments,
            runtimes: runtimes,
            pointerAuthentications: pointerAuthentications,
            objectFormat: objectFormat,
            pointerBitWidth: pointerBitWidth,
            atomicBitWidths: atomicBitWidths,
            endianness: endianness,
            languageVersion: languageVersion,
            compilerVersion: compilerVersion
        )
    }

    public func addingBuildConditions(
        customConditions: Set<String> = [],
        features: Set<String> = []
    ) throws -> ActorGenerationTargetEnvironment {
        try ActorGenerationTargetEnvironment(
            availableModules: availableModules,
            customConditions: self.customConditions.union(customConditions),
            features: self.features.union(features),
            attributes: attributes,
            operatingSystem: operatingSystem,
            architecture: architecture,
            targetEnvironments: targetEnvironments,
            runtimes: runtimes,
            pointerAuthentications: pointerAuthentications,
            objectFormat: objectFormat,
            pointerBitWidth: pointerBitWidth,
            atomicBitWidths: atomicBitWidths,
            endianness: endianness,
            languageVersion: languageVersion,
            compilerVersion: compilerVersion
        )
    }
}

public enum ActorProfileConditionResolver {
    static func validateNoUnresolvedConditions(
        in source: SourceFileSyntax,
        symbol: String
    ) throws {
        func containsConditionalCompilation(_ syntax: Syntax) -> Bool {
            if syntax.is(IfConfigDeclSyntax.self) {
                return true
            }
            return syntax.children(viewMode: .sourceAccurate).contains {
                containsConditionalCompilation($0)
            }
        }
        guard !containsConditionalCompilation(Syntax(source)) else {
            throw ActorGenerationError.invalidTargetEnvironment(
                reason: "A target environment is required before scanning conditional source \(symbol)"
            )
        }
    }

    public static func activeSource(
        _ source: SourceFileSyntax,
        environment: ActorGenerationTargetEnvironment,
        symbol: String
    ) throws -> SourceFileSyntax {
        let result = source.removingInactive(
            in: TargetBuildConfiguration(environment: environment)
        )
        guard result.diagnostics.isEmpty else {
            throw ActorGenerationError.unsupportedDeclaration(
                symbol: symbol,
                reason: "Conditional compilation cannot be resolved for the selected compiler target: \(result.diagnostics.map(\.message).joined(separator: "; "))"
            )
        }
        guard let resolved = result.result.as(SourceFileSyntax.self) else {
            throw ActorGenerationError.unsupportedDeclaration(
                symbol: symbol,
                reason: "Conditional compilation did not produce a Swift source file"
            )
        }
        return resolved
    }

    public static func importedModules(
        in source: SourceFileSyntax,
        environment: ActorGenerationTargetEnvironment,
        symbol: String
    ) throws -> Set<String> {
        let active = try activeSource(
            source,
            environment: environment,
            symbol: symbol
        )
        var modules = Set<String>()
        func collectImports(from syntax: Syntax) {
            if let importDeclaration = syntax.as(ImportDeclSyntax.self),
               let moduleName = importDeclaration.path.trimmedDescription
                .split(separator: ".").first.map(String.init) {
                modules.insert(moduleName)
            }
            for child in syntax.children(viewMode: .sourceAccurate) {
                collectImports(from: child)
            }
        }
        collectImports(from: Syntax(active))
        return modules
    }
}

private struct TargetBuildConfiguration: BuildConfiguration {
    let environment: ActorGenerationTargetEnvironment

    func isCustomConditionSet(name: String) throws -> Bool {
        environment.customConditions.contains(name)
    }

    func hasFeature(name: String) throws -> Bool {
        environment.features.contains(name)
    }

    func hasAttribute(name: String) throws -> Bool {
        guard let attributes = environment.attributes else {
            throw TargetConditionError.unsupported("attribute capability \(name)")
        }
        return attributes.contains(name)
    }

    func canImport(
        importPath: [(TokenSyntax, String)],
        version: CanImportVersion
    ) throws -> Bool {
        guard case .unversioned = version else {
            throw TargetConditionError.unsupported("versioned canImport")
        }
        guard let moduleName = importPath.first?.1 else {
            throw TargetConditionError.unsupported("empty canImport path")
        }
        return environment.availableModules.contains(moduleName)
    }

    func isActiveTargetOS(name: String) throws -> Bool {
        name == environment.operatingSystem
    }

    func isActiveTargetArchitecture(name: String) throws -> Bool {
        name == environment.architecture
    }

    func isActiveTargetEnvironment(name: String) throws -> Bool {
        environment.targetEnvironments.contains(name)
    }

    func isActiveTargetRuntime(name: String) throws -> Bool {
        environment.runtimes.contains(name)
    }

    func isActiveTargetPointerAuthentication(name: String) throws -> Bool {
        guard let pointerAuthentications = environment.pointerAuthentications else {
            throw TargetConditionError.unsupported(
                "pointer authentication capability \(name)"
            )
        }
        return pointerAuthentications.contains(name)
    }

    func isActiveTargetObjectFormat(name: String) throws -> Bool {
        name.lowercased() == environment.objectFormat.lowercased()
    }

    var targetPointerBitWidth: Int {
        environment.pointerBitWidth
    }

    var targetAtomicBitWidths: [Int] {
        environment.atomicBitWidths
    }

    var endianness: Endianness {
        switch environment.endianness {
        case .little: .little
        case .big: .big
        }
    }

    var languageVersion: VersionTuple {
        VersionTuple(components: environment.languageVersion)
    }

    var compilerVersion: VersionTuple {
        VersionTuple(components: environment.compilerVersion)
    }
}

private enum TargetConditionError: Error, CustomStringConvertible {
    case unsupported(String)

    var description: String {
        switch self {
        case .unsupported(let condition):
            "The selected compiler target does not define \(condition)"
        }
    }
}
