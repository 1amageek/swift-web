@testable import ActorSystemBuildSupport
import ActorSystemGeneration
import Testing

@Suite
struct ActorCompilerTargetEnvironmentResolverTests {
    @Test
    func compilerTargetTripleNormalizesCrossTargetPredicates() throws {
        let cortexM = try ParsedTargetTriple("thumbv7em-none-none-eabi")
        #expect(cortexM.architecture == "arm")
        #expect(cortexM.operatingSystem == "none")
        #expect(cortexM.targetEnvironment == "freestanding")
        #expect(cortexM.pointerBitWidth == 32)
        #expect(cortexM.endianness == .little)

        let linux = try ParsedTargetTriple("i686-unknown-linux-gnu")
        #expect(linux.architecture == "i386")
        #expect(linux.operatingSystem == "Linux")
        #expect(linux.pointerBitWidth == 32)

        let wasiPreview = try ParsedTargetTriple("wasm32-unknown-wasip")
        #expect(wasiPreview.architecture == "wasm32")
        #expect(wasiPreview.operatingSystem == "WASI")
        #expect(wasiPreview.objectFormat == "wasm")
    }

    @Test
    func compilerTargetTripleRejectsUnknownArchitectureCapabilities() {
        #expect(throws: ActorGenerationError.self) {
            _ = try ParsedTargetTriple("mystery-none-none-eabi")
        }
    }
}
