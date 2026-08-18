public enum ActorGenerationError: Error, CustomStringConvertible, Sendable {
    case unsupportedDeclaration(symbol: String, reason: String)
    case missingSchemaEntry(symbol: String)
    case missingCompilerTarget(symbol: String, method: String)
    case ambiguousCompilerTarget(symbol: String, method: String, candidates: [String])
    case schemaConflict(reason: String)
    case invalidTargetEnvironment(reason: String)
    case toolchainFailure(command: String, status: Int32, output: String)
    case invalidCompilerOutput(reason: String)
    case sourceWriteFailure(path: String, reason: String)

    public var description: String {
        switch self {
        case .unsupportedDeclaration(let symbol, let reason):
            "Unsupported actor declaration \(symbol): \(reason)"
        case .missingSchemaEntry(let symbol):
            "Actor schema entry is missing for \(symbol)"
        case .missingCompilerTarget(let symbol, let method):
            "Compiler target is missing for \(symbol).\(method)"
        case .ambiguousCompilerTarget(let symbol, let method, let candidates):
            "Compiler target is ambiguous for \(symbol).\(method): \(candidates.joined(separator: ", "))"
        case .schemaConflict(let reason):
            "Actor schema conflict: \(reason)"
        case .invalidTargetEnvironment(let reason):
            "Actor generation target environment is invalid: \(reason)"
        case .toolchainFailure(let command, let status, let output):
            "Toolchain command failed (\(status)): \(command)\n\(output)"
        case .invalidCompilerOutput(let reason):
            "Compiler output is invalid: \(reason)"
        case .sourceWriteFailure(let path, let reason):
            "Failed to write generated actor source at \(path): \(reason)"
        }
    }
}
