#if !hasFeature(Embedded)
// SSE/streaming routes decode Codable search params and stream
// over the native host; full profiles only.
import SwiftWebBrowserRuntime
import SwiftWebHost
import SwiftWebStyle

public struct StreamWriter: Sendable {
    private let writer: (any AsyncBodyStreamWriter)?
    private let buffer: StreamBuffer?
    private let environment: EnvironmentValues

    init(_ writer: any AsyncBodyStreamWriter, environment: EnvironmentValues = EnvironmentValues()) {
        self.writer = writer
        self.buffer = nil
        self.environment = environment
    }

    private init(buffer: StreamBuffer, environment: EnvironmentValues) {
        self.writer = nil
        self.buffer = buffer
        self.environment = environment
    }

    static func collecting(environment: EnvironmentValues = EnvironmentValues()) -> (writer: StreamWriter, buffer: StreamBuffer) {
        let buffer = StreamBuffer()
        return (StreamWriter(buffer: buffer, environment: environment), buffer)
    }

    public func write(_ string: String) async throws {
        if let writer {
            try await writer.write(string)
            return
        }

        if let buffer {
            await buffer.append(string)
        }
    }

    public func write(_ html: some HTML) async throws {
        let styleRegistry = StyleRegistry()
        let documentStyle = DocumentStyle()
        let artifact = StyleRegistry.withCurrent(styleRegistry) {
            DocumentStyle.withCurrent(documentStyle) {
                html.renderArtifact(environment: environment, options: SwiftWebRenderOptions.current)
            }
        }
        SwiftWebDiagnostics.emit(artifact.diagnostics)
        let chunkHTML = SwiftWebHeadAssets.applyStreamedDocumentStyle(
            to: artifact.html,
            registry: styleRegistry,
            document: documentStyle
        )
        try await write(SwiftWebHeadAssets.assets(from: styleRegistry, nonce: environment.cspNonce) + chunkHTML)
    }
}

actor StreamBuffer {
    private var storage = ""

    func append(_ string: String) {
        storage += string
    }

    func output() -> String {
        storage
    }
}
#endif
