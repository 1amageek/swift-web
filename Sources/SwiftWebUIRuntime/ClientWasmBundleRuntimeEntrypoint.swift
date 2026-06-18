import Foundation
import SwiftHTML

public struct ClientWasmComponentRegistration {
    public let typeName: String
    private let makeRuntime: (
        ComponentID,
        StateStore,
        (any BrowserDOMHost)?
    ) -> any RegisteredClientWasmRuntime

    public init<Root: HTML>(
        _ type: Root.Type,
        environmentRegistry: ClientEnvironmentRegistry = .empty,
        rootFactory: @escaping ClientWasmRuntimeBridge<Root>.RootFactory
    ) {
        let registeredTypeName = String(reflecting: type)
        self.typeName = registeredTypeName
        self.makeRuntime = { componentID, stateStore, domHost in
            ClientWasmRegisteredRuntime(
                typeName: registeredTypeName,
                componentID: componentID,
                bridge: ClientWasmRuntimeBridge(
                    environmentRegistry: environmentRegistry,
                    componentMount: ClientWasmComponentMount(
                        typeName: registeredTypeName,
                        componentID: componentID
                    ),
                    domHost: domHost,
                    stateStore: stateStore,
                    rootFactory: rootFactory
                )
            )
        }
    }

    fileprivate func runtime(
        componentID: ComponentID,
        stateStore: StateStore,
        domHost: (any BrowserDOMHost)?
    ) -> any RegisteredClientWasmRuntime {
        makeRuntime(componentID, stateStore, domHost)
    }
}

public final class ClientWasmBundleRuntimeEntrypoint {
    private let responseStorage = ClientWasmResponseStorage()
    private let registrations: [ClientWasmComponentRegistration]
    private let stateStore = StateStore()
    private let domHost: (any BrowserDOMHost)?
    private var runtimesByComponentID: [ComponentID: any RegisteredClientWasmRuntime] = [:]
    private var componentIDByHandlerID: [HandlerID: ComponentID] = [:]
    private var hydrationIndex = BrowserHydrationIndex.empty

    public init(registrations: [ClientWasmComponentRegistration]) {
        self.registrations = registrations
        self.domHost = Self.browserDOMHost()
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
            let response = try bootstrap(request)
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
            let response = try dispatch(request)
            responseStorage.store(response)
            return 0
        } catch {
            responseStorage.storeError(error)
            return 1
        }
    }

    public func snapshotState() -> UInt32 {
        do {
            responseStorage.store(try stateStore.snapshot(schemaHash: currentStateSchemaHash()))
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
            if snapshot.schemaHash == currentStateSchemaHash() {
                stateStore.restore(snapshot)
            }
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

    private func bootstrap(_ request: ClientWasmBootstrapRequest) throws -> ClientWasmRuntimeResponse {
        var currentIndex = request.hydrationIndex
        var commands: [BrowserDOMCommand] = []
        var didApplyCommandsInRuntime = false

        for component in componentsForRegisteredTypes(in: currentIndex) {
            let runtime: any RegisteredClientWasmRuntime
            if let existing = runtimesByComponentID[component.id] {
                runtime = existing
            } else {
                runtime = try makeRuntime(for: component)
            }
            runtimesByComponentID[component.id] = runtime

            let componentRequest = ClientWasmBootstrapRequest(
                hydrationIndex: currentIndex,
                location: request.location,
                mode: request.mode,
                stateSnapshot: request.stateSnapshot
            )
            let response = try runtime.bootstrap(componentRequest)
            if let commandBatch = response.commandBatch {
                commands.append(contentsOf: commandBatch.commands)
            }
            if let nextIndex = response.hydrationIndex {
                currentIndex = nextIndex
            }
            didApplyCommandsInRuntime = didApplyCommandsInRuntime || response.appliesDOMCommandsInRuntime
        }

        hydrationIndex = currentIndex
        rebuildHandlerIndex()
        return ClientWasmRuntimeResponse(
            commandBatch: BrowserDOMCommandBatch(commands: commands),
            hydrationIndex: currentIndex,
            appliesDOMCommandsInRuntime: didApplyCommandsInRuntime
        )
    }

    private func dispatch(_ request: ClientWasmEventRequest) throws -> ClientWasmRuntimeResponse {
        guard let componentID = resolveRuntimeComponentID(for: request),
              let runtime = runtimesByComponentID[componentID]
        else {
            throw ClientWasmRuntimeBridgeError.notBootstrapped
        }

        let response = try runtime.dispatch(request)
        if let nextIndex = response.hydrationIndex {
            hydrationIndex = nextIndex
            rebuildHandlerIndex()
        }
        return response
    }

    /// Resolves the registered runtime component that should handle an event.
    ///
    /// The browser host addresses the event by the handler's immediate component,
    /// which is often a nested, non-registered component (e.g. a `Button`). Only
    /// top-level client components have a registered runtime, so prefer the
    /// requested component only when it actually has one, and otherwise fall back
    /// to the handler-to-registered-component index built during bootstrap.
    private func resolveRuntimeComponentID(
        for request: ClientWasmEventRequest
    ) -> ComponentID? {
        if let requested = request.componentID, runtimesByComponentID[requested] != nil {
            return requested
        }
        if let mapped = componentIDByHandlerID[request.handlerID] {
            return mapped
        }
        return request.componentID
    }

    private func makeRuntime(
        for component: BrowserHydrationComponentRecord
    ) throws -> any RegisteredClientWasmRuntime {
        guard let registration = registration(for: component.typeName) else {
            throw ClientWasmRuntimeBridgeError.componentMountNotFound(component.typeName)
        }
        return registration.runtime(
            componentID: component.id,
            stateStore: stateStore,
            domHost: domHost
        )
    }

    private func componentsForRegisteredTypes(
        in index: BrowserHydrationIndex
    ) -> [BrowserHydrationComponentRecord] {
        index.components.filter { component in
            registration(for: component.typeName) != nil
        }
    }

    private func registration(for typeName: String) -> ClientWasmComponentRegistration? {
        registrations.first { registration in
            typeName == registration.typeName
                || typeName.hasSuffix(".\(registration.typeName)")
                || registration.typeName.hasSuffix(".\(typeName)")
        }
    }

    private func rebuildHandlerIndex() {
        var handlerIndex: [HandlerID: ComponentID] = [:]
        let runtimeComponents = hydrationIndex.components.filter { component in
            runtimesByComponentID[component.id] != nil
        }
        let nodeIDsByComponentID = Dictionary(
            uniqueKeysWithValues: runtimeComponents.map { component in
                (component.id, descendantNodeIDs(from: component.nodeID))
            }
        )

        for binding in hydrationIndex.handlers {
            for component in runtimeComponents {
                guard nodeIDsByComponentID[component.id]?.contains(binding.nodeID) == true else {
                    continue
                }
                handlerIndex[binding.handlerID] = component.id
                break
            }
        }
        componentIDByHandlerID = handlerIndex
    }

    private func descendantNodeIDs(from rootID: HTMLNodeID) -> Set<HTMLNodeID> {
        var result: Set<HTMLNodeID> = []
        func visit(_ nodeID: HTMLNodeID) {
            guard result.insert(nodeID).inserted,
                  let node = hydrationIndex.node(nodeID)
            else {
                return
            }
            for childID in node.childIDs {
                visit(childID)
            }
        }
        visit(rootID)
        return result
    }

    private func currentStateSchemaHash() -> String {
        StateSchema.hash(hydrationIndex.components.flatMap(\.stateSlots))
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

fileprivate protocol RegisteredClientWasmRuntime: AnyObject {
    var componentID: ComponentID { get }
    func bootstrap(_ request: ClientWasmBootstrapRequest) throws -> ClientWasmRuntimeResponse
    func dispatch(_ request: ClientWasmEventRequest) throws -> ClientWasmRuntimeResponse
}

private final class ClientWasmRegisteredRuntime<Root: HTML>: RegisteredClientWasmRuntime {
    let componentID: ComponentID
    private let typeName: String
    private let bridge: ClientWasmRuntimeBridge<Root>

    init(
        typeName: String,
        componentID: ComponentID,
        bridge: ClientWasmRuntimeBridge<Root>
    ) {
        self.typeName = typeName
        self.componentID = componentID
        self.bridge = bridge
    }

    func bootstrap(_ request: ClientWasmBootstrapRequest) throws -> ClientWasmRuntimeResponse {
        try bridge.bootstrap(request)
    }

    func dispatch(_ request: ClientWasmEventRequest) throws -> ClientWasmRuntimeResponse {
        try bridge.dispatch(request)
    }
}
