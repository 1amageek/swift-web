import HTTPTypes
import ServiceContextModule

package enum SwiftWebDevContextCarrier {
    package static let requestIDHeaderName = HTTPField.Name("dev-request-id")!
    package static let workerURLHeaderName = HTTPField.Name("dev-worker-url")!
    package static let phaseHeaderName = HTTPField.Name("dev-phase")!

    package static func extract(from headers: HTTPFields) -> ServiceContext {
        var context = ServiceContext.current ?? ServiceContext.topLevel
        context.swiftWebDevRequestID = headers[requestIDHeaderName]
        context.swiftWebDevWorkerURL = headers[workerURLHeaderName]
        context.swiftWebDevPhase = headers[phaseHeaderName]
        return context
    }

    package static func enrich(
        _ context: inout ServiceContext,
        requestID: String,
        workerURL: String?,
        phase: String
    ) {
        context.swiftWebDevRequestID = requestID
        context.swiftWebDevWorkerURL = workerURL
        context.swiftWebDevPhase = phase
    }

    package static func inject(_ context: ServiceContext, into headers: inout HTTPFields) {
        if let requestID = context.swiftWebDevRequestID {
            headers[requestIDHeaderName] = requestID
        }
        if let workerURL = context.swiftWebDevWorkerURL {
            headers[workerURLHeaderName] = workerURL
        }
        if let phase = context.swiftWebDevPhase {
            headers[phaseHeaderName] = phase
        }
    }
}

private enum SwiftWebDevRequestIDKey: ServiceContextKey {
    typealias Value = String
    static var nameOverride: String? { "dev-request-id" }
}

private enum SwiftWebDevWorkerURLKey: ServiceContextKey {
    typealias Value = String
    static var nameOverride: String? { "dev-worker-url" }
}

private enum SwiftWebDevPhaseKey: ServiceContextKey {
    typealias Value = String
    static var nameOverride: String? { "dev-phase" }
}

extension ServiceContext {
    package var swiftWebDevRequestID: String? {
        get { self[SwiftWebDevRequestIDKey.self] }
        set { self[SwiftWebDevRequestIDKey.self] = newValue }
    }

    package var swiftWebDevWorkerURL: String? {
        get { self[SwiftWebDevWorkerURLKey.self] }
        set { self[SwiftWebDevWorkerURLKey.self] = newValue }
    }

    package var swiftWebDevPhase: String? {
        get { self[SwiftWebDevPhaseKey.self] }
        set { self[SwiftWebDevPhaseKey.self] = newValue }
    }
}
