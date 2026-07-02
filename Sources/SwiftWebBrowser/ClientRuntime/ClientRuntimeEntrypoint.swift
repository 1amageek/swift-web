#if canImport(FoundationEssentials)
import FoundationEssentials
#elseif canImport(Foundation)
import Foundation
#endif
import SwiftHTML
import SwiftWebActors

/// Single-threaded host contract: this type holds unguarded mutable state and is
/// driven exclusively from the JavaScript host through `@_cdecl` exports, which
/// the browser/WASI runtime invokes strictly serially on one thread. It is not
/// `Sendable` and must never be entered re-entrantly (e.g. a microtask that calls
/// back into `dispatchEvent` mid-mutation); doing so would corrupt the response
/// buffer with no compiler guard. The single-threaded WASM environment is what
/// makes the absence of locking sound.
public final class ClientRuntimeEntrypoint<Root: HTML> {
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
        do {
            let request = try decode(
                ClientRuntimeBootstrapRequest.self,
                pointer: pointer,
                length: length
            )
            let response = try bridge.bootstrap(request)
            responseStorage.store(response)
            return 0
        } catch {
            responseStorage.storeError(error)
            return 1
        }
    }

    public func dispatchEvent(pointer: UInt32, length: UInt32) -> UInt32 {
        do {
            let request = try decode(
                ClientRuntimeEventRequest.self,
                pointer: pointer,
                length: length
            )
            let response = try bridge.dispatch(request)
            responseStorage.store(response)
            return 0
        } catch {
            responseStorage.storeError(error)
            return 1
        }
    }

    public func snapshotState() -> UInt32 {
        do {
            responseStorage.store(try bridge.snapshotState())
            return 0
        } catch {
            responseStorage.storeError(error)
            return 1
        }
    }

    public func restoreState(pointer: UInt32, length: UInt32) -> UInt32 {
        do {
            let snapshot = try decode(
                ClientRuntimeStateSnapshot.self,
                pointer: pointer,
                length: length
            )
            bridge.restoreState(snapshot)
            responseStorage.store(ClientRuntimeResponse())
            return 0
        } catch {
            responseStorage.storeError(error)
            return 1
        }
    }

    public func responsePointer() -> UInt32 {
        responseStorage.responsePointer()
    }

    public func responseLength() -> UInt32 {
        responseStorage.responseLength()
    }

    public func freeResponse() {
        responseStorage.free()
    }

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
}

final class ClientRuntimeResponseStorage {
    private var pointer: UnsafeMutableRawPointer?
    private var byteCount: Int = 0

    func store(_ data: Data) {
        free()
        guard !data.isEmpty else {
            return
        }

        let output = UnsafeMutableRawPointer.allocate(
            byteCount: data.count,
            alignment: MemoryLayout<UInt8>.alignment
        )
        data.withUnsafeBytes { buffer in
            if let source = buffer.baseAddress {
                output.copyMemory(from: source, byteCount: data.count)
            }
        }
        pointer = output
        byteCount = data.count
    }

    func store<Response: Encodable>(_ response: Response) {
        do {
            let data = try JSONEncoder().encode(response)
            store(data)
        } catch {
            storeError(error)
        }
    }

    func storeError(_ error: any Error) {
        let response = ClientRuntimeResponse(error: String(describing: error))
        do {
            let data = try JSONEncoder().encode(response)
            store(data)
        } catch {
            store(Data(#"{"error":"SwiftHTML WASM response encoding failed"}"#.utf8))
        }
    }

    func responsePointer() -> UInt32 {
        guard let pointer else {
            return 0
        }
        return UInt32(UInt(bitPattern: pointer))
    }

    func responseLength() -> UInt32 {
        UInt32(byteCount)
    }

    func free() {
        pointer?.deallocate()
        pointer = nil
        byteCount = 0
    }
}
