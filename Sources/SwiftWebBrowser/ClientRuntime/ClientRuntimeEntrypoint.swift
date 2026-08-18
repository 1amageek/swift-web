#if canImport(FoundationEssentials)
import FoundationEssentials
#elseif canImport(Foundation)
import Foundation
#endif
import Synchronization
import SwiftHTML
import SwiftWebActors

public final class ClientRuntimeEntrypoint<Root: Component>: Sendable {
    private let accessGate = ClientRuntimeAccessGate()
    private let responseStorage = ClientRuntimeResponseStorage()
    private let bridge: ClientRuntimeBridge<Root>

    public init(
        environmentRegistry: ClientEnvironmentRegistry = .empty,
        componentMount: ClientComponentMount? = nil,
        actorResolverRegistry: SwiftWebActorResolverRegistry = .empty,
        rootFactory: @escaping ClientRuntimeBridge<Root>.RootFactory
    ) {
        self.bridge = ClientRuntimeBridge(
            environmentRegistry: environmentRegistry,
            componentMount: componentMount,
            domHost: Self.browserDOMHost(),
            actorResolverRegistry: actorResolverRegistry,
            rootFactory: rootFactory
        )
    }

    private static func browserDOMHost() -> (any BrowserDOMHost)? {
        #if os(WASI)
        JavaScriptKitBrowserDOMHost()
        #else
        nil
        #endif
    }

    public func allocate(byteCount: UInt32) -> UInt32 {
        let pointer = UnsafeMutableRawPointer.allocate(
            byteCount: Int(byteCount),
            alignment: MemoryLayout<UInt8>.alignment
        )
        return UInt32(UInt(bitPattern: pointer))
    }

    public func deallocate(pointer: UInt32, byteCount: UInt32) {
        guard let rawPointer = UnsafeMutableRawPointer(bitPattern: Int(pointer)) else {
            return
        }
        rawPointer.deallocate()
    }

    public func bootstrap(pointer: UInt32, length: UInt32) -> UInt32 {
        performOperation {
            #if os(WASI)
            let request = try ClientRuntimeJSONCodec.decodeBootstrapRequest(
                from: inputData(pointer: pointer, length: length)
            )
            #else
            let request = try decode(
                ClientRuntimeBootstrapRequest.self,
                pointer: pointer,
                length: length
            )
            #endif
            let response = try bridge.bootstrap(request)
            try responseStorage.store(response)
        }
    }

    public func dispatchEvent(pointer: UInt32, length: UInt32) -> UInt32 {
        performOperation {
            #if os(WASI)
            let request = try ClientRuntimeJSONCodec.decodeEventRequest(
                from: inputData(pointer: pointer, length: length)
            )
            #else
            let request = try decode(
                ClientRuntimeEventRequest.self,
                pointer: pointer,
                length: length
            )
            #endif
            let response = try bridge.dispatch(request)
            try responseStorage.store(response)
        }
    }

    public func snapshotState() -> UInt32 {
        performOperation {
            try responseStorage.store(bridge.snapshotState())
        }
    }

    public func restoreState(pointer: UInt32, length: UInt32) -> UInt32 {
        performOperation {
            #if os(WASI)
            let snapshot = try ClientRuntimeJSONCodec.decodeStateSnapshot(
                from: inputData(pointer: pointer, length: length)
            )
            #else
            let snapshot = try decode(
                ClientRuntimeStateSnapshot.self,
                pointer: pointer,
                length: length
            )
            #endif
            try bridge.restoreState(snapshot)
            try responseStorage.store(ClientRuntimeResponse())
        }
    }

    public func responseLength() -> UInt32 {
        responseStorage.responseLength()
    }

    public func copyResponse(pointer: UInt32, capacity: UInt32) -> UInt32 {
        responseStorage.copyResponse(pointer: pointer, capacity: capacity)
    }

    public func freeResponse() {
        responseStorage.free()
    }

    public func shutdown() async throws {
        try await bridge.shutdown()
    }

    private func performOperation(_ operation: () throws -> Void) -> UInt32 {
        do {
            return try accessGate.withExclusiveAccess {
                do {
                    try operation()
                    return 0
                } catch {
                    responseStorage.storeError(error)
                    return 1
                }
            }
        } catch {
            return 2
        }
    }

    #if !hasFeature(Embedded)
    private func decode<Request: Decodable>(
        _ type: Request.Type,
        pointer: UInt32,
        length: UInt32
    ) throws -> Request {
        guard let rawPointer = UnsafeRawPointer(bitPattern: Int(pointer)) else {
            throw ClientRuntimeEntrypointError.invalidInputPointer
        }
        let data = Data(bytes: rawPointer, count: Int(length))
        return try JSONDecoder().decode(Request.self, from: data)
    }
    #endif

    private func inputData(pointer: UInt32, length: UInt32) throws -> ClientRuntimeWireData {
        try ClientRuntimeWireDataFactory.copy(pointer: pointer, length: length)
    }
}

final class ClientRuntimeResponseStorage: Sendable {
    private let storage = Mutex(ClientRuntimeWireData())
    private let responseEncoder: @Sendable (ClientRuntimeResponse) throws -> ClientRuntimeWireData
    private let snapshotEncoder: @Sendable (ClientRuntimeStateSnapshot) throws -> ClientRuntimeWireData

    init() {
        self.responseEncoder = Self.encodeResponse
        self.snapshotEncoder = Self.encodeSnapshot
    }

    init(
        responseEncoder: @escaping @Sendable (ClientRuntimeResponse) throws -> ClientRuntimeWireData
    ) {
        self.responseEncoder = responseEncoder
        self.snapshotEncoder = Self.encodeSnapshot
    }

    func store(_ data: ClientRuntimeWireData) {
        storage.withLock { $0 = data }
    }

    func store(_ response: ClientRuntimeResponse) throws {
        store(try responseEncoder(response))
    }

    func store(_ snapshot: ClientRuntimeStateSnapshot) throws {
        store(try snapshotEncoder(snapshot))
    }

    func storeError(_ error: any Error) {
        #if hasFeature(Embedded)
        _ = error
        let errorDescription = "SwiftHTML Embedded WASM runtime operation failed"
        #else
        let errorDescription = String(describing: error)
        #endif
        let response = ClientRuntimeResponse(error: errorDescription)
        do {
            store(try responseEncoder(response))
        } catch {
            store(ClientRuntimeWireDataFactory.utf8(
                #"{"error":"SwiftHTML WASM response encoding failed"}"#
            ))
        }
    }

    func responseLength() -> UInt32 {
        storage.withLock { UInt32($0.count) }
    }

    func copyResponse(pointer: UInt32, capacity: UInt32) -> UInt32 {
        guard let destination = UnsafeMutableRawPointer(bitPattern: Int(pointer)) else {
            return 0
        }
        return UInt32(copyResponse(to: destination, capacity: Int(capacity)))
    }

    func copyResponse(to destination: UnsafeMutableRawPointer, capacity: Int) -> Int {
        return storage.withLock { data in
            guard data.count <= capacity else {
                return 0
            }
            data.withUnsafeBytes { source in
                if let baseAddress = source.baseAddress, !data.isEmpty {
                    destination.copyMemory(from: baseAddress, byteCount: data.count)
                }
            }
            return data.count
        }
    }

    func free() {
        storage.withLock { $0 = ClientRuntimeWireData() }
    }

    private static func encodeResponse(
        _ response: ClientRuntimeResponse
    ) throws -> ClientRuntimeWireData {
        #if os(WASI)
        try ClientRuntimeJSONCodec.encode(response)
        #else
        try JSONEncoder().encode(response)
        #endif
    }

    private static func encodeSnapshot(
        _ snapshot: ClientRuntimeStateSnapshot
    ) throws -> ClientRuntimeWireData {
        #if os(WASI)
        try ClientRuntimeJSONCodec.encode(snapshot)
        #else
        try JSONEncoder().encode(snapshot)
        #endif
    }
}
