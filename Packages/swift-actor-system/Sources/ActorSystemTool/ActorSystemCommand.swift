import ActorSystemBuildSupport
import ActorSystemGeneration
import Foundation

@main
struct ActorSystemCommand {
    static func main() throws {
        var arguments = Array(CommandLine.arguments.dropFirst())
        guard let command = arguments.first else {
            throw CommandError.usage
        }
        arguments.removeFirst()
        switch command {
        case "generate":
            try generate(arguments)
        case "project":
            try project(arguments)
        case "schema":
            try schema(arguments)
        default:
            throw CommandError.unknownCommand(command)
        }
    }

    private static func project(_ arguments: [String]) throws {
        let options = try ParsedOptions(arguments)
        let moduleName = try options.required("module")
        let packageIdentity = try options.required("package")
        let sourceRoot = try options.optional("source-root").map {
            URL(fileURLWithPath: $0, isDirectory: true)
        }
        let schemaLock = URL(fileURLWithPath: try options.required("lock"))
        let output = URL(fileURLWithPath: try options.required("output"))
        let swiftCompiler = URL(fileURLWithPath: try options.required("swiftc"))
        let toolchainFingerprint = try options.optional("toolchain-fingerprint")
        let actorSystemTypeName = try options.optional("actor-system-type")
            ?? "SwiftActorSystem"
        let includedActorSystemTypes = Set(options.values("include-actor-system"))
        guard let profile = ActorGenerationProfile(
            rawValue: try options.required("profile")
        ) else {
            throw CommandError.invalidOption("profile")
        }
        let sources = options.values("source").map(URL.init(fileURLWithPath:))
        guard !sources.isEmpty else {
            throw CommandError.missingOption("source")
        }
        let dependencySchemas = try options.values("dependency-schema").map { path in
            let url = URL(fileURLWithPath: path)
            let data = try Data(contentsOf: url)
            return try ActorSchemaLockStore.decode(data)
        }
        let compilerArguments = options.values("compiler-arg")
        let targetEnvironment = try ActorCompilerTargetEnvironmentResolver.resolve(
            swiftCompiler: swiftCompiler,
            compilerArguments: compilerArguments,
            availableModules: Set(options.values("available-module"))
                .union(dependencySchemas.map(\.moduleName))
        )
        let fingerprint = try ActorToolchainFingerprint.compute(
            swiftCompiler: swiftCompiler
        )
        _ = try ActorSystemCompiler.project(
            ActorSystemProjectionRequest(
                sourceFiles: sources,
                sourceRoot: sourceRoot,
                moduleName: moduleName,
                packageIdentity: packageIdentity,
                profile: profile,
                schemaLockURL: schemaLock,
                outputDirectory: output,
                toolchainFingerprint: fingerprint,
                expectedToolchainFingerprint: toolchainFingerprint,
                dependencySchemas: dependencySchemas,
                distributedActorSystemTypeName: actorSystemTypeName,
                includedActorSystemTypeNames: includedActorSystemTypes.isEmpty
                    ? nil
                    : includedActorSystemTypes,
                targetEnvironment: targetEnvironment
            )
        )
    }

    private static func generate(_ arguments: [String]) throws {
        let options = try ParsedOptions(arguments)
        let moduleName = try options.required("module")
        let packageIdentity = try options.required("package")
        let sourceRoot = try options.optional("source-root").map {
            URL(fileURLWithPath: $0, isDirectory: true)
        }
        let schemaLock = URL(fileURLWithPath: try options.required("lock"))
        let output = URL(fileURLWithPath: try options.required("output"))
        let swiftCompiler = URL(fileURLWithPath: try options.required("swiftc"))
        let toolchainFingerprint = try options.optional("toolchain-fingerprint")
        let actorSystemTypeName = try options.optional("actor-system-type")
            ?? "SwiftActorSystem"
        let includedActorSystemTypes = Set(options.values("include-actor-system"))
        guard let profile = ActorGenerationProfile(
            rawValue: try options.required("profile")
        ) else {
            throw CommandError.invalidOption("profile")
        }
        let sources = options.values("source").map(URL.init(fileURLWithPath:))
        guard !sources.isEmpty else {
            throw CommandError.missingOption("source")
        }
        let dependencySchemas = try options.values("dependency-schema").map { path in
            let url = URL(fileURLWithPath: path)
            let data = try Data(contentsOf: url)
            return try ActorSchemaLockStore.decode(data)
        }
        let extraction = ActorCompilerTargetExtractionRequest(
            swiftCompiler: swiftCompiler,
            moduleName: moduleName,
            sourceFiles: sources,
            additionalCompilerArguments: options.values("compiler-arg")
        )
        let targetEnvironment = try ActorCompilerTargetEnvironmentResolver.resolve(
            swiftCompiler: swiftCompiler,
            compilerArguments: extraction.additionalCompilerArguments,
            availableModules: Set(options.values("available-module"))
                .union(dependencySchemas.map(\.moduleName))
        )
        _ = try ActorSystemCompiler.compile(
            ActorSystemCompilationRequest(
                sourceFiles: sources,
                sourceRoot: sourceRoot,
                moduleName: moduleName,
                packageIdentity: packageIdentity,
                profile: profile,
                schemaLockURL: schemaLock,
                outputDirectory: output,
                toolchainFingerprint: try ActorToolchainFingerprint.compute(
                    swiftCompiler: swiftCompiler
                ),
                expectedToolchainFingerprint: toolchainFingerprint,
                compilerTargetMappingProvider: extraction,
                dependencySchemas: dependencySchemas,
                distributedActorSystemTypeName: actorSystemTypeName,
                includedActorSystemTypeNames: includedActorSystemTypes.isEmpty
                    ? nil
                    : includedActorSystemTypes,
                targetEnvironment: targetEnvironment
            )
        )
    }

    private static func schema(_ arguments: [String]) throws {
        guard let operation = arguments.first else {
            throw CommandError.usage
        }
        let options = try ParsedOptions(Array(arguments.dropFirst()))
        let lockURL = URL(fileURLWithPath: try options.required("lock"))
        let packageIdentity = try options.required("package")
        let values = options.positionals
        guard values.count == 2 else {
            throw CommandError.usage
        }
        let lock = try ActorSchemaLockStore.load(
            from: lockURL,
            packageIdentity: packageIdentity
        )
        let moved: ActorSchemaLock
        switch operation {
        case "move":
            moved = try ActorSchemaReconciler.moveActor(
                in: lock,
                from: values[0],
                to: values[1]
            )
        case "move-value":
            moved = try ActorSchemaReconciler.moveValueType(
                in: lock,
                from: values[0],
                to: values[1]
            )
        case "move-field":
            moved = try ActorSchemaReconciler.moveValueField(
                in: lock,
                valueType: try options.required("type"),
                from: values[0],
                to: values[1]
            )
        case "move-case":
            moved = try ActorSchemaReconciler.moveEnumCase(
                in: lock,
                valueType: try options.required("type"),
                from: values[0],
                to: values[1]
            )
        case "move-actor-field":
            moved = try ActorSchemaReconciler.moveActorField(
                in: lock,
                actorSymbol: try options.required("actor"),
                from: values[0],
                to: values[1]
            )
        default:
            throw CommandError.unknownCommand("schema \(operation)")
        }
        try ActorSchemaLockStore.save(moved, to: lockURL)
    }
}

private struct ParsedOptions {
    private var storage: [String: [String]] = [:]
    let positionals: [String]

    init(_ arguments: [String]) throws {
        var storage: [String: [String]] = [:]
        var positionals: [String] = []
        var index = 0
        while index < arguments.count {
            let argument = arguments[index]
            guard argument.hasPrefix("--") else {
                positionals.append(argument)
                index += 1
                continue
            }
            let name = String(argument.dropFirst(2))
            guard !name.isEmpty, index + 1 < arguments.count else {
                throw CommandError.invalidOption(name)
            }
            storage[name, default: []].append(arguments[index + 1])
            index += 2
        }
        self.storage = storage
        self.positionals = positionals
    }

    func required(_ name: String) throws -> String {
        guard let values = storage[name], values.count == 1, let value = values.first else {
            throw CommandError.missingOption(name)
        }
        return value
    }

    func values(_ name: String) -> [String] {
        storage[name] ?? []
    }

    func optional(_ name: String) throws -> String? {
        guard let values = storage[name] else {
            return nil
        }
        guard values.count == 1 else {
            throw CommandError.invalidOption(name)
        }
        return values[0]
    }
}

private enum CommandError: Error, CustomStringConvertible {
    case usage
    case unknownCommand(String)
    case missingOption(String)
    case invalidOption(String)

    var description: String {
        switch self {
        case .usage:
            "Usage: actor-system generate|project|schema move|move-value|move-field|move-case|move-actor-field"
        case .unknownCommand(let command):
            "Unknown actor-system command: \(command)"
        case .missingOption(let option):
            "Missing actor-system option: --\(option)"
        case .invalidOption(let option):
            "Invalid actor-system option: --\(option)"
        }
    }
}
