import SwiftWebBrowserRuntime
import NIOCore
import SwiftWebStyle
import Vapor

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
            let buffer = ByteBufferAllocator().buffer(string: string)
            try await writer.write(.buffer(buffer))
            return
        }

        if let buffer {
            await buffer.append(string)
        }
    }

    public func write(_ html: some HTML) async throws {
        let styleRegistry = StyleRegistry()
        let artifact = StyleRegistry.withCurrent(styleRegistry) {
            html.renderArtifact(environment: environment, options: SwiftWebRenderOptions.current)
        }
        SwiftWebDiagnostics.emit(artifact.diagnostics)
        try await write(SwiftWebHeadAssets.assets(from: styleRegistry, nonce: environment.cspNonce) + artifact.html)
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
