import ActorSystemCore
import JavaScriptEventLoop
import JavaScriptKit
import SwiftWebUIRuntime

@main
struct BoundaryProbe {
    static func main() {
        JSObject.global.probeStage = .string("swift.main.install")
        JavaScriptEventLoop.installGlobalExecutor()
        JSObject.global.probeStage = .string("swift.main.task")
        Task.detached {
            JSObject.global.probeStage = .string("swift.detached.entered")
            await MainActor.run {
                JSObject.global.probeStage = .string("swift.mainActor.entered")
            }
            do {
                try await run()
                JSObject.global.probeDone = .boolean(true)
            } catch {
                JSObject.global.probeFailure = .string("Actor transport boundary assertion failed; inspect probeStage")
            }
        }
    }

    @MainActor
    static func run() async throws {
        JSObject.global.probeStage = .string("swift.configuration")
        let configuration = ActorSystemConfiguration(
            sessionIdentitySource: FixedActorSessionIdentitySource(ActorSessionID(71)),
            maximumFrameBytes: 1_048_832,
            maximumPayloadBytes: 1_048_576
        )
        let codec = ActorFrameCodec(configuration: configuration)
        JSObject.global.probeStage = .string("swift.frames")
        let endpoint = ActorEndpoint("/actor")
        for branch in ["fetch", "host"] {
            for count in [0, 1_048_576] {
                let payload = ActorByteBuffer((0..<count).map { UInt8(truncatingIfNeeded: $0) })
                let callID = ActorCallID(session: ActorSessionID(71), sequence: 1)
                let frame = ActorFrame.invocation(ActorInvocationFrame(
                    callID: callID,
                    invocation: ActorInvocation(
                        recipient: ActorAddress(type: ActorTypeID(high: 7, low: 8), identity: "boundary"),
                        method: ActorMethodID(9),
                        schemaFingerprint: ActorSchemaFingerprint(high: 10, low: 11),
                        payload: payload
                    ),
                    remainingTimeoutNanoseconds: nil
                ))
                let result = ActorFrame.result(ActorResultFrame(
                    callID: callID, outcome: .success(ActorInvocationResult(payload: payload))
                ))
                // Fixture preparation is outside the measured transport interval.
                JSObject.global.probeStage = .string("swift.encode")
                let request = JSUint8Array(try codec.encode(frame).bytes)
                let response = JSUint8Array(try codec.encode(result).bytes)
                _ = JSObject.global.probePrepare!(branch, count, request, response)
                let transport = JavaScriptKitActorTransport(configuration: configuration)
                try await transport.start()
                var incoming = transport.incoming.makeAsyncIterator()
                _ = JSObject.global.probeBegin!()
                try await transport.send(frame, to: endpoint)
                _ = JSObject.global.probeEnd!()
                guard try await incoming.next()?.frame == result else { throw ActorSystemError.decodingFailed }

                _ = JSObject.global.probeMode!("unavailable")
                do {
                    try await transport.send(frame, to: endpoint)
                    throw ActorSystemError.encodingFailed
                } catch ActorSystemError.overloaded {}

                _ = JSObject.global.probeMode!("empty")
                do {
                    try await transport.send(frame, to: endpoint)
                    throw ActorSystemError.encodingFailed
                } catch ActorSystemError.invalidFrame {}

                _ = JSObject.global.probeMode!("pending")
                let pending = Task { try await transport.send(frame, to: endpoint) }
                while JSObject.global.probeEntered.boolean != true { await Task.yield() }
                pending.cancel()
                do {
                    try await pending.value
                    throw ActorSystemError.encodingFailed
                } catch ActorSystemError.cancelled {}
                await transport.shutdown()
                do {
                    try await transport.send(frame, to: endpoint)
                    throw ActorSystemError.encodingFailed
                } catch ActorSystemError.transportClosed {}
                guard try await incoming.next() == nil else { throw ActorSystemError.decodingFailed }
                _ = JSObject.global.probeVerified!()
            }
        }
    }
}
