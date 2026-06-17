import Foundation
import SwiftHTML

public final class ClientWasmRuntimeEntrypoint<Root: HTML> {
    private let responseStorage = ClientWasmResponseStorage()
    private let bridge: ClientWasmRuntimeBridge<Root>

    public init(
        environmentRegistry: ClientEnvironmentRegistry = .empty,
        componentMount: ClientWasmComponentMount? = nil,
        rootFactory: @escaping ClientWasmRuntimeBridge<Root>.RootFactory
    ) {
        self.bridge = ClientWasmRuntimeBridge(
            environmentRegistry: environmentRegistry,
            componentMount: componentMount,
            domHost: Self.browserDOMHost(),
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
                ClientWasmBootstrapRequest.self,
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
                ClientWasmEventRequest.self,
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
                ClientWasmStateSnapshot.self,
                pointer: pointer,
                length: length
            )
            bridge.restoreState(snapshot)
            responseStorage.store(ClientWasmRuntimeResponse())
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
            throw ClientWasmRuntimeEntrypointError.invalidInputPointer
        }
        let data = Data(bytes: rawPointer, count: Int(length))
        return try JSONDecoder().decode(Request.self, from: data)
    }
}

final class ClientWasmResponseStorage {
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
        let response = ClientWasmRuntimeResponse(error: String(describing: error))
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
