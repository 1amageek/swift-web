@testable import ActorSystemBuildSupport
@testable import ActorSystemGeneration
import Testing

@Suite
struct CompilerTargetExtractorTests {
    @Test
    func controlledSilProbeMapsExactCompilerLiteral() throws {
        let probe = fixtureProbe()
        let target = "$s7Fixture7CounterC9increment2byS2i_tYaKFTE"
        let sil = """
        // __actorSystemTargetProbe_0(_:_:)
        // Isolation: unspecified
        sil hidden @probe : $@convention(thin) () -> () {
          %0 = witness_method $System, #DistributedActorSystem.remoteCall
          %1 = string_literal utf8 "\(target)"
        }
        """

        let mappings = try CompilerTargetExtractor.parse(sil: sil, probes: [probe])

        #expect(mappings == [ActorCompilerTargetMapping(key: probe.key, targetIdentifier: target)])
    }

    @Test
    func probeFollowsFunctionReferenceToDistributedMethodThunk() throws {
        let probe = fixtureProbe()
        let target = "$s7Fixture7CounterC9increment2byS2i_tYaKFTE"
        let sil = """
        // __actorSystemTargetProbe_0(_:_:)
        sil hidden @probe : $@convention(thin) () -> () {
          %0 = function_ref @distributed_thunk : $@convention(thin) () -> ()
        }
        // distributed thunk
        sil hidden @distributed_thunk : $@convention(thin) () -> () {
          %0 = witness_method $System, #DistributedActorSystem.remoteCall
          %1 = string_literal utf8 "\(target)"
        }
        """

        let mappings = try CompilerTargetExtractor.parse(sil: sil, probes: [probe])

        #expect(mappings == [ActorCompilerTargetMapping(key: probe.key, targetIdentifier: target)])
    }

    @Test
    func concreteActorSystemDirectRemoteCallMapsExactCompilerLiteral() throws {
        let probe = fixtureProbe()
        let target = "$s7Fixture7CounterC9increment2byS2i_tYaKFTE"
        let sil = """
        // __actorSystemTargetProbe_0(_:_:)
        sil hidden @probe : $@convention(thin) () -> () {
          %0 = function_ref @distributed_thunk : $@convention(thin) () -> ()
        }
        // distributed thunk
        sil hidden @distributed_thunk : $@convention(thin) () -> () {
          %0 = alloc_stack $RemoteCallTarget
          // function_ref WebActorSystem.remoteCall<A, B, C>(on:target:invocation:throwing:returning:)
          %1 = function_ref @concrete_remote_call : $@convention(thin) () -> ()
          %2 = string_literal utf8 "\(target)"
        }
        """

        let mappings = try CompilerTargetExtractor.parse(sil: sil, probes: [probe])

        #expect(mappings == [ActorCompilerTargetMapping(key: probe.key, targetIdentifier: target)])
    }

    @Test
    func compilerTargetIgnoresRemoteArgumentMetadataLiteral() throws {
        let probe = fixtureProbe()
        let target = "$s7Fixture7CounterC9increment2byS2i_tYaKFTE"
        let sil = """
        // __actorSystemTargetProbe_0(_:_:)
        sil hidden @probe : $@convention(thin) () -> () {
          %0 = witness_method $System, #DistributedActorSystem.remoteCall
          %1 = string_literal utf8 "amount"
          %2 = string_literal utf8 "\(target)"
        }
        """

        let mappings = try CompilerTargetExtractor.parse(sil: sil, probes: [probe])

        #expect(mappings == [ActorCompilerTargetMapping(key: probe.key, targetIdentifier: target)])
    }

    @Test
    func ambiguousCompilerLiteralsFailWithoutGuessing() throws {
        let probe = fixtureProbe()
        let sil = """
        // __actorSystemTargetProbe_0(_:_:)
        sil hidden @probe : $@convention(thin) () -> () {
          %0 = witness_method $System, #DistributedActorSystem.remoteCall
          %1 = string_literal utf8 "first"
          %2 = string_literal utf8 "second"
        }
        """

        #expect(throws: ActorGenerationError.self) {
            _ = try CompilerTargetExtractor.parse(sil: sil, probes: [probe])
        }
    }

    @Test
    func missingDistributedRequirementFailsEvenWithOneLiteral() throws {
        let probe = fixtureProbe()
        let sil = """
        // __actorSystemTargetProbe_0(_:_:)
        sil hidden @probe : $@convention(thin) () -> () {
          %0 = string_literal utf8 "looks-plausible"
        }
        """

        #expect(throws: ActorGenerationError.self) {
            _ = try CompilerTargetExtractor.parse(sil: sil, probes: [probe])
        }
    }

    private func fixtureProbe() -> ActorCompilerProbe {
        let method = ActorMethodModel(
            name: "increment",
            parameters: [
                ActorParameterModel(
                    externalName: "by",
                    localName: "amount",
                    type: "Int",
                    defaultValue: nil
                ),
            ],
            returnType: "Int",
            isAsync: true,
            throwsClause: "throws",
            body: "amount",
            accessLevel: "internal"
        )
        let key = ActorCompilerTargetKey(
            actorSymbol: "Fixture.Counter",
            canonicalMethodSignature: method.canonicalSignature
        )
        return ActorCompilerProbe(
            functionName: "__actorSystemTargetProbe_0",
            actorType: "Counter",
            method: method,
            key: key
        )
    }
}
