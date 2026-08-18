import ActorSystemGeneration
import Foundation

public struct ActorCompilerTargetExtractionRequest: Sendable {
    public let swiftCompiler: URL
    public let moduleName: String
    public let sourceFiles: [URL]
    public let additionalCompilerArguments: [String]

    public init(
        swiftCompiler: URL,
        moduleName: String,
        sourceFiles: [URL],
        additionalCompilerArguments: [String] = []
    ) {
        self.swiftCompiler = swiftCompiler
        self.moduleName = moduleName
        self.sourceFiles = sourceFiles
        self.additionalCompilerArguments = additionalCompilerArguments
    }
}

extension ActorCompilerTargetExtractionRequest: ActorCompilerTargetMappingProvider {
    public func mappings(
        for actors: [ActorSourceModel]
    ) throws -> [ActorCompilerTargetMapping] {
        try CompilerTargetExtractor.extract(actors: actors, request: self)
    }
}

public enum CompilerTargetExtractor {
    public static func extract(
        actors: [ActorSourceModel],
        request: ActorCompilerTargetExtractionRequest
    ) throws -> [ActorCompilerTargetMapping] {
        let probes = probeModels(actors: actors)
        let temporaryDirectory = FileManager.default.temporaryDirectory
            .appendingPathComponent("swift-actor-system-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(
            at: temporaryDirectory,
            withIntermediateDirectories: true
        )
        defer {
            do {
                try FileManager.default.removeItem(at: temporaryDirectory)
            } catch {
                // Temporary cleanup failure does not change compiler extraction semantics.
            }
        }

        let probeURL = temporaryDirectory.appendingPathComponent("ActorSystemTargetProbes.swift")
        let silURL = temporaryDirectory.appendingPathComponent("ActorSystemTargetProbes.sil")
        let diagnosticsURL = temporaryDirectory.appendingPathComponent("compiler-diagnostics.txt")
        let probeValueFunctionName = "__actorSystemProbeValue_\(UUID().uuidString.replacingOccurrences(of: "-", with: "_"))"
        try renderProbeSource(
            probes: probes,
            valueFunctionName: probeValueFunctionName
        ).write(
            to: probeURL,
            atomically: true,
            encoding: .utf8
        )

        var arguments = [
            "-emit-silgen",
            "-whole-module-optimization",
            "-module-name", request.moduleName,
        ]
        arguments.append(contentsOf: request.additionalCompilerArguments)
        arguments.append(contentsOf: request.sourceFiles.map(\.path))
        arguments.append(probeURL.path)
        arguments.append(contentsOf: ["-o", silURL.path])

        guard FileManager.default.createFile(
            atPath: diagnosticsURL.path,
            contents: nil
        ) else {
            throw ActorGenerationError.sourceWriteFailure(
                path: diagnosticsURL.path,
                reason: "Cannot create compiler diagnostics output"
            )
        }
        let diagnosticsHandle = try FileHandle(forWritingTo: diagnosticsURL)
        defer {
            do {
                try diagnosticsHandle.close()
            } catch {
                // The compiler exit status remains the authoritative result.
            }
        }
        let process = Process()
        process.executableURL = request.swiftCompiler
        process.arguments = arguments
        process.standardOutput = diagnosticsHandle
        process.standardError = diagnosticsHandle
        try process.run()
        process.waitUntilExit()
        try diagnosticsHandle.synchronize()

        let diagnosticsData = try Data(contentsOf: diagnosticsURL)
        let diagnostics = String(decoding: diagnosticsData, as: UTF8.self)
        guard process.terminationStatus == 0 else {
            throw ActorGenerationError.toolchainFailure(
                command: ([request.swiftCompiler.path] + arguments).joined(separator: " "),
                status: process.terminationStatus,
                output: diagnostics
            )
        }
        let sil = try String(contentsOf: silURL, encoding: .utf8)
        return try parse(sil: sil, probes: probes)
    }

    static func parse(
        sil: String,
        probes: [ActorCompilerProbe]
    ) throws -> [ActorCompilerTargetMapping] {
        let functions = silFunctions(sil)
        let functionsBySymbol = Dictionary(grouping: functions, by: \.symbol)
        var mappings: [ActorCompilerTargetMapping] = []
        for probe in probes {
            let candidates = functions.filter { function in
                function.commentName.hasPrefix(probe.functionName + "(")
                    || function.commentName == probe.functionName
            }
            guard candidates.count == 1, let function = candidates.first else {
                if candidates.isEmpty {
                    throw ActorGenerationError.missingCompilerTarget(
                        symbol: probe.key.actorSymbol,
                        method: probe.key.canonicalMethodSignature
                    )
                }
                throw ActorGenerationError.ambiguousCompilerTarget(
                    symbol: probe.key.actorSymbol,
                    method: probe.key.canonicalMethodSignature,
                    candidates: candidates.map(\.commentName)
                )
            }
            let remoteCallFunctions = firstReachableRemoteCallFunctions(
                from: function,
                functionsBySymbol: functionsBySymbol
            )
            guard !remoteCallFunctions.isEmpty else {
                throw ActorGenerationError.invalidCompilerOutput(
                    reason: "Probe \(probe.functionName) cannot reach a DistributedActorSystem remote-call requirement"
                )
            }
            let targetLiterals = Array(Set(remoteCallFunctions.flatMap {
                stringLiterals(in: $0.body)
            })).sorted()
            guard targetLiterals.count == 1, let target = targetLiterals.first else {
                if targetLiterals.isEmpty {
                    throw ActorGenerationError.missingCompilerTarget(
                        symbol: probe.key.actorSymbol,
                        method: probe.key.canonicalMethodSignature
                    )
                }
                throw ActorGenerationError.ambiguousCompilerTarget(
                    symbol: probe.key.actorSymbol,
                    method: probe.key.canonicalMethodSignature,
                    candidates: targetLiterals
                )
            }
            mappings.append(ActorCompilerTargetMapping(key: probe.key, targetIdentifier: target))
        }
        return mappings
    }

    private static func firstReachableRemoteCallFunctions(
        from root: SILFunction,
        functionsBySymbol: [String: [SILFunction]]
    ) -> [SILFunction] {
        var pending = [root]
        var visited: Set<String> = []
        var matches: [SILFunction] = []

        while !pending.isEmpty {
            let level = pending
            pending.removeAll(keepingCapacity: true)
            for function in level {
                guard visited.insert(function.symbol).inserted else {
                    continue
                }
                if containsDistributedRemoteCall(function.body) {
                    matches.append(function)
                    continue
                }
                for symbol in referencedSymbols(in: function.body).sorted() {
                    pending.append(contentsOf: functionsBySymbol[symbol] ?? [])
                }
            }
            if !matches.isEmpty {
                return matches
            }
        }
        return []
    }

    private static func containsDistributedRemoteCall(_ body: String) -> Bool {
        if body.contains("#DistributedActorSystem.remoteCall")
            || body.contains("#DistributedActorSystem.remoteCallVoid") {
            return true
        }
        let hasConcreteRemoteCall = body.contains("// function_ref ")
            && (body.contains(".remoteCall<") || body.contains(".remoteCallVoid<"))
        return hasConcreteRemoteCall && body.contains("$RemoteCallTarget")
    }

    private static func referencedSymbols(in functionBody: String) -> Set<String> {
        var symbols: Set<String> = []
        for line in functionBody.split(separator: "\n") {
            let text = String(line)
            for marker in ["function_ref @", "dynamic_function_ref @"] {
                guard let range = text.range(of: marker),
                      let symbol = symbolPrefix(text[range.upperBound...])
                else {
                    continue
                }
                symbols.insert(symbol)
            }
        }
        return symbols
    }

    private static func probeModels(actors: [ActorSourceModel]) -> [ActorCompilerProbe] {
        var probes: [ActorCompilerProbe] = []
        for actor in actors {
            for method in actor.methods {
                probes.append(
                    ActorCompilerProbe(
                        functionName: "__actorSystemTargetProbe_\(probes.count)",
                        actorType: actor.name,
                        method: method,
                        key: ActorCompilerTargetKey(
                            actorSymbol: actor.symbol,
                            canonicalMethodSignature: method.canonicalSignature
                        )
                    )
                )
            }
        }
        return probes
    }

    private static func renderProbeSource(
        probes: [ActorCompilerProbe],
        valueFunctionName: String
    ) -> String {
        var lines = [
            "import Distributed",
            "",
            "@inline(never)",
            "func \(valueFunctionName)<Value>() -> Value {",
            "    fatalError()",
            "}",
        ]
        lines.append("")
        for probe in probes {
            let arguments = probe.method.parameters.map { parameter in
                let label = parameter.externalName == "_" ? "" : "\(parameter.externalName): "
                return "\(label)\(valueFunctionName)()"
            }.joined(separator: ", ")
            lines.append("@inline(never)")
            lines.append("func \(probe.functionName)(_ actor: \(probe.actorType)) async throws {")
            lines.append("    _ = try await actor.\(probe.method.name)(\(arguments))")
            lines.append("}")
            lines.append("")
        }
        return lines.joined(separator: "\n")
    }

    private static func silFunctions(_ sil: String) -> [SILFunction] {
        let lines = sil.split(separator: "\n", omittingEmptySubsequences: false).map(String.init)
        var functions: [SILFunction] = []
        var pendingComment: String?
        var activeName: String?
        var activeSymbol: String?
        var activeLines: [String] = []
        var braceDepth = 0

        for line in lines {
            if activeName == nil, line.hasPrefix("// ") {
                if pendingComment == nil {
                    pendingComment = String(line.dropFirst(3))
                }
                continue
            }
            if activeName == nil, line.hasPrefix("sil "), line.hasSuffix("{"),
               let symbol = silDeclarationSymbol(in: line) {
                activeName = pendingComment ?? ""
                activeSymbol = symbol
                activeLines = [line]
                braceDepth = 1
                pendingComment = nil
                continue
            }
            guard activeName != nil else {
                if !line.trimmingCharacters(in: .whitespaces).isEmpty {
                    pendingComment = nil
                }
                continue
            }
            activeLines.append(line)
            braceDepth += line.filter { $0 == "{" }.count
            braceDepth -= line.filter { $0 == "}" }.count
            if braceDepth == 0, let name = activeName, let symbol = activeSymbol {
                functions.append(
                    SILFunction(
                        commentName: name,
                        symbol: symbol,
                        body: activeLines.joined(separator: "\n")
                    )
                )
                activeName = nil
                activeSymbol = nil
                activeLines = []
            }
        }
        return functions
    }

    private static func silDeclarationSymbol(in line: String) -> String? {
        guard let marker = line.firstIndex(of: "@") else {
            return nil
        }
        return symbolPrefix(line[line.index(after: marker)...])
    }

    private static func symbolPrefix(_ source: Substring) -> String? {
        let end = source.firstIndex { character in
            character == " " || character == "\t" || character == ":"
        } ?? source.endIndex
        guard end > source.startIndex else {
            return nil
        }
        return String(source[..<end])
    }

    private static func stringLiterals(in functionBody: String) -> [String] {
        var literals: [String] = []
        for line in functionBody.split(separator: "\n") {
            guard let marker = line.range(of: "string_literal utf8 \"") else {
                continue
            }
            let start = marker.upperBound
            guard let end = line[start...].lastIndex(of: "\"") else {
                continue
            }
            let literal = String(line[start..<end])
            guard !literal.contains("\\") else {
                continue
            }
            literals.append(literal)
        }
        return literals
    }
}

struct ActorCompilerProbe: Hashable, Sendable {
    let functionName: String
    let actorType: String
    let method: ActorMethodModel
    let key: ActorCompilerTargetKey
}

private struct SILFunction {
    let commentName: String
    let symbol: String
    let body: String
}
