#if canImport(FoundationEssentials)
import FoundationEssentials
#elseif canImport(Foundation)
import Foundation
#endif
import Synchronization
import SwiftHTML
import SwiftWebActors

public struct ClientComponentRegistration: Sendable {
    public let typeName: String
    private let makeRuntime: @Sendable (
        ComponentID,
        StateStore,
        (any BrowserDOMHost)?
    ) -> any RegisteredClientRuntime

    public init<Root: Component>(
        _ type: Root.Type,
        environmentRegistry: ClientEnvironmentRegistry = .empty,
        actorResolverRegistry: SwiftWebActorResolverRegistry = .empty,
        rootFactory: @escaping ClientRuntimeBridge<Root>.RootFactory
    ) {
        let registeredTypeName = String(reflecting: type)
        self.typeName = registeredTypeName
        self.makeRuntime = { componentID, stateStore, domHost in
            ClientRegisteredRuntime(
                typeName: registeredTypeName,
                componentID: componentID,
                bridge: ClientRuntimeBridge(
                    environmentRegistry: environmentRegistry,
                    componentMount: ClientComponentMount(
                        typeName: registeredTypeName,
                        componentID: componentID
                    ),
                    domHost: domHost,
                    stateStore: stateStore,
                    actorResolverRegistry: actorResolverRegistry,
                    rootFactory: rootFactory
                )
            )
        }
    }

    fileprivate func runtime(
        componentID: ComponentID,
        stateStore: StateStore,
        domHost: (any BrowserDOMHost)?
    ) -> any RegisteredClientRuntime {
        makeRuntime(componentID, stateStore, domHost)
    }
}

public final class ClientBundleRuntimeEntrypoint: Sendable {
    private struct RuntimeEntry: Sendable {
        let componentID: ComponentID
        let componentPath: String
        let runtime: any RegisteredClientRuntime
    }

    private struct RuntimeState: Sendable {
        var runtimeEntries: [RuntimeEntry] = []
        var runtimeIndexByHandlerID = HandlerRuntimeMap()
        var hydrationIndex = BrowserHydrationIndex.empty
    }

    private let accessGate = ClientRuntimeAccessGate()
    private let responseStorage: ClientRuntimeResponseStorage
    private let registrations: [ClientComponentRegistration]
    private let domHost: (any BrowserDOMHost)?
    private let runtimeState = Mutex(RuntimeState())

    public init(registrations: [ClientComponentRegistration]) {
        self.registrations = registrations
        self.domHost = Self.browserDOMHost()
        self.responseStorage = ClientRuntimeResponseStorage()
    }

    init(
        registrations: [ClientComponentRegistration],
        domHost: (any BrowserDOMHost)?,
        responseStorage: ClientRuntimeResponseStorage = ClientRuntimeResponseStorage()
    ) {
        self.registrations = registrations
        self.domHost = domHost
        self.responseStorage = responseStorage
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
            let response = try bootstrap(request)
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
            let response = try dispatch(request)
            try responseStorage.store(response)
        }
    }

    public func snapshotState() -> UInt32 {
        performOperation {
            try responseStorage.store(try snapshotStateValue())
        }
    }

    func snapshotStateValue() throws -> ClientRuntimeStateSnapshot {
        let entries = runtimeState.withLock { $0.runtimeEntries }
        var values: [String: StateSnapshotValue] = [:]
        for entry in entries {
            let snapshot = try entry.runtime.snapshotState()
            for (key, value) in snapshot.values {
                let namespacedKey = Self.namespacedStateKey(
                    namespace: entry.componentPath,
                    localKey: key
                )
                guard values.updateValue(value, forKey: namespacedKey) == nil else {
                    throw ClientRuntimeBridgeError.duplicateStateSlot(namespacedKey)
                }
            }
        }
        return ClientRuntimeStateSnapshot(
            schemaHash: currentStateSchemaHash(),
            values: values
        )
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
            if snapshot.schemaHash == currentStateSchemaHash() {
                let entries = runtimeState.withLock { $0.runtimeEntries }
                for entry in entries {
                    try entry.runtime.restoreState(
                        Self.componentSnapshot(snapshot, namespace: entry.componentPath)
                    )
                }
            }
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

    func bootstrapStatus(_ request: ClientRuntimeBootstrapRequest) -> UInt32 {
        performOperation {
            try responseStorage.store(try bootstrap(request))
        }
    }

    func dispatchStatus(_ request: ClientRuntimeEventRequest) -> UInt32 {
        performOperation {
            try responseStorage.store(try dispatch(request))
        }
    }

    func copyResponse(to destination: UnsafeMutableRawPointer, capacity: Int) -> Int {
        responseStorage.copyResponse(to: destination, capacity: capacity)
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

    func bootstrap(_ request: ClientRuntimeBootstrapRequest) throws -> ClientRuntimeResponse {
        var currentIndex = request.hydrationIndex
        var commands: [BrowserDOMCommand] = []
        var atomicStyleRules: [ClientRuntimeAtomicStyleRule] = []
        var runtimeEntries: [RuntimeEntry] = []

        for component in componentsForRegisteredTypes(in: currentIndex) {
            let runtime = try makeRuntime(for: component, domHost: nil)
            runtimeEntries.append(
                RuntimeEntry(
                    componentID: component.id,
                    componentPath: component.path,
                    runtime: runtime
                )
            )

            let componentRequest = ClientRuntimeBootstrapRequest(
                hydrationIndex: currentIndex,
                documentNodeIDUpperBound: request.documentNodeIDUpperBound,
                location: request.location,
                mode: request.mode,
                stateSnapshot: request.stateSnapshot.map {
                    Self.componentSnapshot($0, namespace: component.path)
                },
                actorBindings: request.actorBindings
            )
            let response = try runtime.bootstrap(componentRequest)
            if let commandBatch = response.commandBatch {
                commands.append(contentsOf: commandBatch.commands)
            }
            atomicStyleRules.append(contentsOf: response.atomicStyleRules)
            if let nextIndex = response.hydrationIndex {
                currentIndex = nextIndex
            }
        }

        let commandBatch = BrowserDOMCommandBatch(commands: commands)
        let appliesDOMCommandsInRuntime = domHost != nil && request.mode != .hotReload
        if appliesDOMCommandsInRuntime, let domHost, !commands.isEmpty {
            try domHost.apply(commandBatch, currentIndex: request.hydrationIndex)
        }
        let runtimeIndexByHandlerID = Self.handlerIndex(
            hydrationIndex: currentIndex,
            runtimeEntries: runtimeEntries
        )
        runtimeState.withLock { state in
            state.runtimeEntries = runtimeEntries
            state.runtimeIndexByHandlerID = runtimeIndexByHandlerID
            state.hydrationIndex = currentIndex
        }
        return ClientRuntimeResponse(
            commandBatch: commandBatch,
            hydrationIndex: currentIndex,
            atomicStyleRules: atomicStyleRules,
            appliesDOMCommandsInRuntime: appliesDOMCommandsInRuntime
        )
    }

    func dispatch(_ request: ClientRuntimeEventRequest) throws -> ClientRuntimeResponse {
        let state = runtimeState.withLock { state in
            (
                runtimeEntries: state.runtimeEntries,
                runtimeIndexByHandlerID: state.runtimeIndexByHandlerID,
                hydrationIndex: state.hydrationIndex
            )
        }
        guard let runtimeIndex = Self.resolveRuntimeIndex(
            for: request,
            runtimeEntries: state.runtimeEntries,
            runtimeIndexByHandlerID: state.runtimeIndexByHandlerID
        ) else {
            throw ClientRuntimeBridgeError.notBootstrapped
        }
        let runtime = state.runtimeEntries[runtimeIndex].runtime

        let response = try runtime.dispatch(request)
        if let nextIndex = response.hydrationIndex {
            let runtimeIndexByHandlerID = Self.handlerIndex(
                hydrationIndex: nextIndex,
                runtimeEntries: state.runtimeEntries
            )
            runtimeState.withLock { state in
                state.hydrationIndex = nextIndex
                state.runtimeIndexByHandlerID = runtimeIndexByHandlerID
            }
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
    private static func resolveRuntimeIndex(
        for request: ClientRuntimeEventRequest,
        runtimeEntries: [RuntimeEntry],
        runtimeIndexByHandlerID: HandlerRuntimeMap
    ) -> Int? {
        if let mapped = runtimeIndexByHandlerID.runtimeIndex(
            for: request.handlerID,
            componentID: request.componentID
        ),
           runtimeEntries.indices.contains(mapped) {
            return mapped
        }
        if let requested = request.componentID {
            return runtimeEntries.firstIndex { $0.componentID == requested }
        }
        return nil
    }

    private func makeRuntime(
        for component: BrowserHydrationComponentRecord,
        domHost: (any BrowserDOMHost)?
    ) throws -> any RegisteredClientRuntime {
        guard let registration = registration(for: component.typeName) else {
            throw ClientRuntimeBridgeError.componentMountNotFound(component.typeName)
        }
        return registration.runtime(
            componentID: component.id,
            stateStore: StateStore(),
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

    private func registration(for typeName: String) -> ClientComponentRegistration? {
        registrations.first { registration in
            typeName == registration.typeName
                || typeName.hasSuffix(".\(registration.typeName)")
                || registration.typeName.hasSuffix(".\(typeName)")
        }
    }

    private static func handlerIndex(
        hydrationIndex: BrowserHydrationIndex,
        runtimeEntries: [RuntimeEntry]
    ) -> HandlerRuntimeMap {
        var handlerIndex = HandlerRuntimeMap()
        let componentsByPath = hydrationIndex.components.sorted { $0.path < $1.path }
        var runtimeComponents: [BrowserHydrationComponentRecord] = []
        var componentPriorityByRootNodeID = NodeMap()
        for (runtimeIndex, entry) in runtimeEntries.enumerated() {
            guard let component = component(path: entry.componentPath, in: componentsByPath) else {
                continue
            }
            runtimeComponents.append(component)
            componentPriorityByRootNodeID[component.nodeID] = HTMLNodeID(runtimeIndex)
        }
        var ownerPriorityByNodeID = NodeMap()
        var visited = NodeIDSet()
        func recordOwnership(from nodeID: HTMLNodeID, inheritedPriority: Int?) {
            guard visited.insert(nodeID) else {
                return
            }
            let priority = componentPriorityByRootNodeID[nodeID]?.rawValue ?? inheritedPriority
            if let priority {
                ownerPriorityByNodeID[nodeID] = HTMLNodeID(priority)
            }
            guard let node = hydrationIndex.node(nodeID) else {
                return
            }
            for childID in node.childIDs {
                recordOwnership(from: childID, inheritedPriority: priority)
            }
        }
        recordOwnership(from: hydrationIndex.rootID, inheritedPriority: nil)
        for component in runtimeComponents where !visited.contains(component.nodeID) {
            recordOwnership(from: component.nodeID, inheritedPriority: nil)
        }
        for binding in hydrationIndex.handlers {
            if let priority = ownerPriorityByNodeID[binding.nodeID]?.rawValue,
               runtimeEntries.indices.contains(priority) {
                handlerIndex.appendUnsorted(
                    priority,
                    for: binding.handlerID,
                    componentID: binding.componentID
                )
            }
        }
        handlerIndex.prepareForLookup()
        return handlerIndex
    }

    private static func component(
        path: String,
        in sortedComponents: [BrowserHydrationComponentRecord]
    ) -> BrowserHydrationComponentRecord? {
        var lowerBound = 0
        var upperBound = sortedComponents.count
        while lowerBound < upperBound {
            let midpoint = lowerBound + (upperBound - lowerBound) / 2
            if sortedComponents[midpoint].path < path {
                lowerBound = midpoint + 1
            } else {
                upperBound = midpoint
            }
        }
        guard lowerBound < sortedComponents.count,
              sortedComponents[lowerBound].path == path else {
            return nil
        }
        return sortedComponents[lowerBound]
    }

    private func currentStateSchemaHash() -> String {
        runtimeState.withLock { state in
            StateSchema.hash(state.hydrationIndex.components.flatMap(\.stateSlots))
        }
    }

    private static func componentSnapshot(
        _ snapshot: ClientRuntimeStateSnapshot,
        namespace: String
    ) -> ClientRuntimeStateSnapshot {
        let prefix = stateKeyPrefix(for: namespace)
        var values: [String: StateSnapshotValue] = [:]
        for (key, value) in snapshot.values where key.hasPrefix(prefix) {
            values[String(key.dropFirst(prefix.count))] = value
        }
        return ClientRuntimeStateSnapshot(schemaHash: snapshot.schemaHash, values: values)
    }

    private static func namespacedStateKey(
        namespace: String,
        localKey: String
    ) -> String {
        stateKeyPrefix(for: namespace) + localKey
    }

    private static func stateKeyPrefix(for value: String) -> String {
        return "\(value.utf8.count):\(value):"
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

    private func inputData(pointer: UInt32, length: UInt32) throws -> Data {
        guard let rawPointer = UnsafeRawPointer(bitPattern: Int(pointer)) else {
            throw ClientRuntimeEntrypointError.invalidInputPointer
        }
        return Data(bytes: rawPointer, count: Int(length))
    }
}

fileprivate protocol RegisteredClientRuntime: AnyObject, Sendable {
    var componentID: ComponentID { get }
    func bootstrap(_ request: ClientRuntimeBootstrapRequest) throws -> ClientRuntimeResponse
    func dispatch(_ request: ClientRuntimeEventRequest) throws -> ClientRuntimeResponse
    func snapshotState() throws -> ClientRuntimeStateSnapshot
    func restoreState(_ snapshot: ClientRuntimeStateSnapshot) throws
}

private final class ClientRegisteredRuntime<Root: Component>: RegisteredClientRuntime {
    let componentID: ComponentID
    private let typeName: String
    private let bridge: ClientRuntimeBridge<Root>

    init(
        typeName: String,
        componentID: ComponentID,
        bridge: ClientRuntimeBridge<Root>
    ) {
        self.typeName = typeName
        self.componentID = componentID
        self.bridge = bridge
    }

    func bootstrap(_ request: ClientRuntimeBootstrapRequest) throws -> ClientRuntimeResponse {
        try bridge.bootstrap(request)
    }

    func dispatch(_ request: ClientRuntimeEventRequest) throws -> ClientRuntimeResponse {
        try bridge.dispatch(request)
    }

    func snapshotState() throws -> ClientRuntimeStateSnapshot {
        try bridge.snapshotState()
    }

    func restoreState(_ snapshot: ClientRuntimeStateSnapshot) throws {
        try bridge.restoreState(snapshot)
    }
}
