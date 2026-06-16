@preconcurrency import ActorRuntime
@preconcurrency import Distributed
import Foundation

public struct WebActorResultHandler: DistributedTargetInvocationResultHandler, Sendable {
    public typealias SerializationRequirement = Codable & Sendable

    private let callID: String
    private let sendResponse: @Sendable (ResponseEnvelope) async throws -> Void

    public init(
        callID: String,
        sendResponse: @Sendable @escaping (ResponseEnvelope) async throws -> Void
    ) {
        self.callID = callID
        self.sendResponse = sendResponse
    }

    public func onReturn<Success>(value: Success) async throws where Success: Codable & Sendable {
        let data = try JSONEncoder().encode(value)
        try await sendResponse(ResponseEnvelope(callID: callID, result: .success(data)))
    }

    public func onReturnVoid() async throws {
        try await sendResponse(ResponseEnvelope(callID: callID, result: .void))
    }

    public func onThrow<Err>(error: Err) async throws where Err: Error {
        let runtimeError: RuntimeError
        if let error = error as? RuntimeError {
            runtimeError = error
        } else {
            runtimeError = .executionFailed(
                String(describing: error),
                underlying: String(reflecting: error)
            )
        }
        try await sendResponse(ResponseEnvelope(callID: callID, result: .failure(runtimeError)))
    }
}
