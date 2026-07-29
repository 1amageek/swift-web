import SwiftHTML
import SwiftWebActors
import SwiftWebStyle
import Synchronization

public struct ClientRuntimeBootstrapLocation: Sendable, Codable, Equatable {
    public let href: String
    public let search: String

    public init(href: String, search: String) {
        self.href = href
        self.search = search
    }
}

public struct ClientRuntimeBootstrapRequest: Sendable, Codable, Equatable {
    public let hydrationIndex: BrowserHydrationIndex
    public let documentNodeIDUpperBound: Int?
    public let location: ClientRuntimeBootstrapLocation
    public let mode: ClientRuntimeBootstrapMode?
    public let stateSnapshot: ClientRuntimeStateSnapshot?
    public let actorBindings: [SwiftWebActorBindingRecord]

    public init(
        hydrationIndex: BrowserHydrationIndex,
        documentNodeIDUpperBound: Int? = nil,
        location: ClientRuntimeBootstrapLocation,
        mode: ClientRuntimeBootstrapMode? = nil,
        stateSnapshot: ClientRuntimeStateSnapshot? = nil,
        actorBindings: [SwiftWebActorBindingRecord] = []
    ) {
        self.hydrationIndex = hydrationIndex
        self.documentNodeIDUpperBound = documentNodeIDUpperBound
        self.location = location
        self.mode = mode
        self.stateSnapshot = stateSnapshot
        self.actorBindings = actorBindings
    }

}

public enum ClientRuntimeBootstrapMode: String, Sendable, Codable, Equatable {
    case standard
    case hotReload
    case navigation
}

public typealias ClientRuntimeStateSnapshot = StateStoreSnapshot

public struct ClientRuntimeAtomicStyleRule: Sendable, Codable, Equatable {
    public let className: String
    public let body: String

    public init(className: String, body: String) {
        self.className = className
        self.body = body
    }
}

public struct ClientRuntimeEventRequest: Sendable, Codable, Equatable {
    public let handlerID: HandlerID
    public let event: DOMEvent
    public let componentID: ComponentID?

    public init(
        handlerID: HandlerID,
        event: DOMEvent,
        componentID: ComponentID? = nil
    ) {
        self.handlerID = handlerID
        self.event = event
        self.componentID = componentID
    }
}

public struct ClientRuntimeResponse: Sendable, Codable, Equatable {
    public let commandBatch: BrowserDOMCommandBatch?
    public let hydrationIndex: BrowserHydrationIndex?
    public let atomicStyleRules: [ClientRuntimeAtomicStyleRule]
    public let error: String?
    public let appliesDOMCommandsInRuntime: Bool

    public init(
        commandBatch: BrowserDOMCommandBatch? = nil,
        hydrationIndex: BrowserHydrationIndex? = nil,
        atomicStyleRules: [ClientRuntimeAtomicStyleRule] = [],
        error: String? = nil,
        appliesDOMCommandsInRuntime: Bool = false
    ) {
        self.commandBatch = commandBatch
        self.hydrationIndex = hydrationIndex
        self.atomicStyleRules = atomicStyleRules
        self.error = error
        self.appliesDOMCommandsInRuntime = appliesDOMCommandsInRuntime
    }
}

public enum ClientRuntimeBridgeError: Error, Sendable, CustomStringConvertible {
    case notBootstrapped
    case componentMountNotFound(String)
    case duplicateStateSlot(String)

    public var description: String {
        switch self {
        case .notBootstrapped:
            "SwiftHTML browser runtime was not bootstrapped"
        case .componentMountNotFound(let typeName):
            "SwiftHTML browser component mount was not found for \(typeName)"
        case .duplicateStateSlot(let slotID):
            "SwiftHTML browser runtime produced duplicate state slot \(slotID)"
        }
    }
}

public struct ClientComponentMount: Sendable, Equatable {
    public let typeName: String
    public let componentID: ComponentID?

    public init<Root: Component>(_ type: Root.Type) {
        self.typeName = String(reflecting: type)
        self.componentID = nil
    }

    public init(typeName: String, componentID: ComponentID? = nil) {
        self.typeName = typeName
        self.componentID = componentID
    }
}

public final class ClientRuntimeBridge<Root: Component>: Sendable {
    private struct StableDOMSignatureRecord {
        let nodeID: HTMLNodeID
        let signature: String
    }

    private struct StableDOMSignatureIndex {
        let recordsByNodeID: [StableDOMSignatureRecord]
        let recordsBySignature: [StableDOMSignatureRecord]

        init(_ records: [StableDOMSignatureRecord]) {
            self.recordsByNodeID = records.sorted { left, right in
                left.nodeID.rawValue < right.nodeID.rawValue
            }
            self.recordsBySignature = records.sorted { left, right in
                left.signature < right.signature
            }
        }

        func signature(for nodeID: HTMLNodeID) -> String? {
            var lowerBound = 0
            var upperBound = recordsByNodeID.count
            while lowerBound < upperBound {
                let middle = lowerBound + (upperBound - lowerBound) / 2
                if recordsByNodeID[middle].nodeID.rawValue < nodeID.rawValue {
                    lowerBound = middle + 1
                } else {
                    upperBound = middle
                }
            }
            guard lowerBound < recordsByNodeID.count,
                  recordsByNodeID[lowerBound].nodeID == nodeID else {
                return nil
            }
            return recordsByNodeID[lowerBound].signature
        }

        func nodeID(for signature: String) -> HTMLNodeID? {
            var lowerBound = 0
            var upperBound = recordsBySignature.count
            while lowerBound < upperBound {
                let middle = lowerBound + (upperBound - lowerBound) / 2
                if recordsBySignature[middle].signature < signature {
                    lowerBound = middle + 1
                } else {
                    upperBound = middle
                }
            }
            guard lowerBound < recordsBySignature.count,
                  recordsBySignature[lowerBound].signature == signature else {
                return nil
            }
            return recordsBySignature[lowerBound].nodeID
        }
    }

    private struct MountedComponentByNodeIndex {
        let records: [BrowserHydrationComponentRecord]

        init(_ records: [BrowserHydrationComponentRecord]) {
            self.records = records.sorted { $0.nodeID.rawValue < $1.nodeID.rawValue }
        }

        func record(for nodeID: HTMLNodeID) -> BrowserHydrationComponentRecord? {
            ClientRuntimeBridge.binarySearch(records, nodeID: nodeID, key: \.nodeID)
        }
    }

    private struct MountedServerSlotByNodeIndex {
        let records: [ServerSlotRecord]

        init(_ records: [ServerSlotRecord]) {
            self.records = records.sorted { $0.nodeID.rawValue < $1.nodeID.rawValue }
        }

        func record(for nodeID: HTMLNodeID) -> ServerSlotRecord? {
            ClientRuntimeBridge.binarySearch(records, nodeID: nodeID, key: \.nodeID)
        }
    }

    private struct MountedHandlerIndex {
        let records: [BrowserHydrationEventBinding]

        init(_ records: [BrowserHydrationEventBinding]) {
            self.records = records.sorted { left, right in
                if left.nodeID != right.nodeID {
                    return left.nodeID.rawValue < right.nodeID.rawValue
                }
                return left.eventName < right.eventName
            }
        }

        func handlerID(for nodeID: HTMLNodeID, eventName: String) -> HandlerID? {
            var lowerBound = 0
            var upperBound = records.count
            while lowerBound < upperBound {
                let midpoint = lowerBound + (upperBound - lowerBound) / 2
                let candidate = records[midpoint]
                if candidate.nodeID.rawValue < nodeID.rawValue
                    || (candidate.nodeID == nodeID && candidate.eventName < eventName) {
                    lowerBound = midpoint + 1
                } else {
                    upperBound = midpoint
                }
            }
            guard lowerBound < records.count,
                  records[lowerBound].nodeID == nodeID,
                  records[lowerBound].eventName == eventName else {
                return nil
            }
            return records[lowerBound].handlerID
        }
    }

    private struct MountedKeyedChildIndex {
        private struct Entry {
            let signature: String
            let node: BrowserHydrationNodeRecord
        }

        private let entries: [Entry]

        init(childIDs: [HTMLNodeID], index: BrowserHydrationIndex) {
            var entries: [Entry] = []
            entries.reserveCapacity(childIDs.count)
            for childID in childIDs {
                guard let node = index.node(childID), let key = node.key else {
                    continue
                }
                entries.append(Entry(signature: Self.signature(for: key), node: node))
            }
            self.entries = entries.sorted { $0.signature < $1.signature }
        }

        func nodeID(
            for key: Key,
            compatibleWith localNode: BrowserHydrationNodeRecord,
            excluding usedIDs: NodeIDSet
        ) -> HTMLNodeID? {
            let signature = Self.signature(for: key)
            var lowerBound = 0
            var upperBound = entries.count
            while lowerBound < upperBound {
                let midpoint = lowerBound + (upperBound - lowerBound) / 2
                if entries[midpoint].signature < signature {
                    lowerBound = midpoint + 1
                } else {
                    upperBound = midpoint
                }
            }
            var cursor = lowerBound
            while cursor < entries.count, entries[cursor].signature == signature {
                let mountedNode = entries[cursor].node
                if !usedIDs.contains(mountedNode.id),
                   mountedNode.key == key,
                   mountedNode.role == localNode.role,
                   mountedNode.name == localNode.name,
                   (mountedNode.componentID != nil) == (localNode.componentID != nil),
                   (mountedNode.serverSlotID != nil) == (localNode.serverSlotID != nil) {
                    return mountedNode.id
                }
                cursor += 1
            }
            return nil
        }

        private static func signature(for key: Key) -> String {
            "\(key.identity.utf8.count):\(key.identity)\(key.rawValue)"
        }
    }

    private static func binarySearch<Record>(
        _ records: [Record],
        nodeID: HTMLNodeID,
        key: KeyPath<Record, HTMLNodeID>
    ) -> Record? {
        var lowerBound = 0
        var upperBound = records.count
        while lowerBound < upperBound {
            let midpoint = lowerBound + (upperBound - lowerBound) / 2
            if records[midpoint][keyPath: key].rawValue < nodeID.rawValue {
                lowerBound = midpoint + 1
            } else {
                upperBound = midpoint
            }
        }
        guard lowerBound < records.count,
              records[lowerBound][keyPath: key] == nodeID else {
            return nil
        }
        return records[lowerBound]
    }

    private struct RuntimeState: Sendable {
        var session: HydrationRuntimeSession<Root>?
        var mountedHydrationIndex: BrowserHydrationIndex?
        var mountedNodeMap = NodeMap()
        var mountedToLocalNodeMap = NodeMap()
        var documentNodeIDUpperBound: Int?
        var actorBindingScope: SwiftWebActorBindingScope?
    }

    public typealias RootFactory = @Sendable (ClientRuntimeBootstrapRequest) throws -> Root
    public typealias EnvironmentFactory = @Sendable (ClientRuntimeBootstrapRequest) throws -> EnvironmentValues
    public typealias ComponentEnvironmentFactory = @Sendable (
        ClientRuntimeBootstrapRequest,
        EnvironmentValues
    ) throws -> [String: EnvironmentValues]

    private let rootFactory: RootFactory
    private let environmentFactory: EnvironmentFactory
    private let componentEnvironmentFactory: ComponentEnvironmentFactory
    private let componentMount: ClientComponentMount?
    private let domHost: (any BrowserDOMHost)?
    private let stateStore: StateStore
    private let actorResolverRegistry: SwiftWebActorResolverRegistry
    private let actorSystem: WebActorSystem
    private let accessGate = ClientRuntimeAccessGate()
    private let runtimeState = Mutex(RuntimeState())

    public init(
        environmentRegistry: ClientEnvironmentRegistry = .empty,
        componentMount: ClientComponentMount? = nil,
        domHost: (any BrowserDOMHost)? = nil,
        stateStore: StateStore = StateStore(),
        actorResolverRegistry: SwiftWebActorResolverRegistry = .empty,
        actorSystem: WebActorSystem? = nil,
        rootFactory: @escaping RootFactory
    ) {
        self.rootFactory = rootFactory
        self.componentMount = componentMount
        self.domHost = domHost
        self.stateStore = stateStore
        self.actorResolverRegistry = actorResolverRegistry
        self.actorSystem = actorSystem ?? Self.defaultActorSystem()
        self.environmentFactory = { request in
            // A mounted component renders with local paths that never match the
            // server index's page-level paths, so path-keyed overrides cannot
            // deliver values provided outside the mount (scene/page
            // `.environment()`). Those values are uniform across the mounted
            // subtree: decode the mount's own snapshot into the session's root
            // environment instead. `.environment()` applied inside the
            // component content re-executes during client rendering and needs no
            // restoration.
            guard let componentMount,
                  let mounted = Self.component(in: request.hydrationIndex, matching: componentMount),
                  !mounted.environmentSnapshot.values.isEmpty
            else {
                return EnvironmentValues()
            }
            return try environmentRegistry.environment(
                from: mounted.environmentSnapshot,
                base: EnvironmentValues()
            )
        }
        self.componentEnvironmentFactory = { request, base in
            try environmentRegistry.componentEnvironments(from: request.hydrationIndex, base: base)
        }
    }

    public init(
        componentMount: ClientComponentMount? = nil,
        domHost: (any BrowserDOMHost)? = nil,
        stateStore: StateStore = StateStore(),
        actorResolverRegistry: SwiftWebActorResolverRegistry = .empty,
        actorSystem: WebActorSystem? = nil,
        rootFactory: @escaping RootFactory,
        environmentFactory: @escaping EnvironmentFactory,
        componentEnvironmentFactory: @escaping ComponentEnvironmentFactory = { _, _ in [:] }
    ) {
        self.rootFactory = rootFactory
        self.componentMount = componentMount
        self.domHost = domHost
        self.stateStore = stateStore
        self.actorResolverRegistry = actorResolverRegistry
        self.actorSystem = actorSystem ?? Self.defaultActorSystem()
        self.environmentFactory = environmentFactory
        self.componentEnvironmentFactory = componentEnvironmentFactory
    }

    public func bootstrap(_ request: ClientRuntimeBootstrapRequest) throws -> ClientRuntimeResponse {
        try accessGate.withExclusiveAccess {
            let actorBindingScope = SwiftWebActorBindingScope(
                records: request.actorBindings,
                resolverRegistry: actorResolverRegistry,
                actorSystem: actorSystem
            )
            return try SwiftWebActorBindingContext.withValue(actorBindingScope) {
                try bootstrapWithCurrentActorBindings(
                    request,
                    actorBindingScope: actorBindingScope
                )
            }
        }
    }

    private func bootstrapWithCurrentActorBindings(
        _ request: ClientRuntimeBootstrapRequest,
        actorBindingScope: SwiftWebActorBindingScope
    ) throws -> ClientRuntimeResponse {
        let root = try rootFactory(request)
        let environment = try environmentFactory(request)
        let componentEnvironmentOverrides = try componentEnvironmentFactory(request, environment)
        let options = HTMLRenderOptions(
            recordsDiagnostics: true,
            capturesClientHandlerClosures: true,
            emitsBrowserHydrationMarkers: true,
            componentEnvironmentOverrides: componentEnvironmentOverrides
        )
        // Collect atomic CSS used while rendering the initial tree.
        let styleRegistry = StyleRegistry()
        let session = try StyleRegistry.withCurrent(styleRegistry) {
            try makeSession(
                root: root,
                environment: environment,
                options: options,
                restoring: request.stateSnapshot
            )
        }
        let atomicStyleRules = styleRegistry.rules().map {
            ClientRuntimeAtomicStyleRule(className: $0.className, body: $0.body)
        }
        if let componentMount {
            let localIndex = session.artifact.browserHydrationIndex()
            let initialNodeMap = try Self.nodeMap(
                localIndex: localIndex,
                mountedIndex: request.hydrationIndex,
                mount: componentMount
            )
            if request.mode == .hotReload {
                let nextNodeMap = Self.structuralNodeMap(
                    localIndex: localIndex,
                    mountedIndex: request.hydrationIndex,
                    mount: componentMount,
                    documentNodeIDUpperBound: request.documentNodeIDUpperBound
                )
                let previousNodeMap = Self.boundaryNodeMap(
                    mountedIndex: request.hydrationIndex,
                    mount: componentMount
                )
                let commandBatch = Self.hotReloadCommandBatch(
                    localArtifact: session.artifact,
                    localIndex: localIndex,
                    mountedIndex: request.hydrationIndex,
                    nodeMap: nextNodeMap,
                    mount: componentMount
                )
                let nextHydrationIndex = Self.rebased(
                    localIndex,
                    mountedIndex: request.hydrationIndex,
                    previousNodeMap: previousNodeMap,
                    nodeMap: nextNodeMap,
                    mount: componentMount
                )
                if let domHost {
                    try domHost.apply(commandBatch, currentIndex: request.hydrationIndex)
                }
                runtimeState.withLock { state in
                    state.session = session
                    state.mountedHydrationIndex = nextHydrationIndex
                    state.mountedNodeMap = nextNodeMap
                    state.mountedToLocalNodeMap = nextNodeMap.inverted()
                    state.documentNodeIDUpperBound = request.documentNodeIDUpperBound
                    state.actorBindingScope = actorBindingScope
                }
                return ClientRuntimeResponse(
                    commandBatch: commandBatch,
                    hydrationIndex: nextHydrationIndex,
                    atomicStyleRules: atomicStyleRules,
                    appliesDOMCommandsInRuntime: domHost != nil
                )
            }
            // Normalize the mounted DOM's event attributes to the local
            // render's handler ids. The server rendered the whole document
            // with one handler counter while the island renders with its own,
            // so the two id spaces disagree from the first paint; rewriting
            // the attributes once here makes the DOM speak the local id space,
            // and every later re-render keeps it in sync through the
            // fingerprint-aware attribute diff.
            let syncBatch = BrowserDOMCommandBatch(
                commands: Self.eventAttributeSyncCommands(
                    localIndex: localIndex,
                    nodeMap: initialNodeMap
                )
            )
            if let domHost, !syncBatch.commands.isEmpty {
                try domHost.apply(syncBatch, currentIndex: request.hydrationIndex)
            }
            runtimeState.withLock { state in
                state.session = session
                state.mountedHydrationIndex = request.hydrationIndex
                state.mountedNodeMap = initialNodeMap
                state.mountedToLocalNodeMap = initialNodeMap.inverted()
                state.documentNodeIDUpperBound = request.documentNodeIDUpperBound
                state.actorBindingScope = actorBindingScope
            }
            return ClientRuntimeResponse(
                commandBatch: syncBatch,
                hydrationIndex: request.hydrationIndex,
                atomicStyleRules: atomicStyleRules,
                appliesDOMCommandsInRuntime: domHost != nil
            )
        }

        let hydrationIndex = session.artifact.browserHydrationIndex()
        runtimeState.withLock { state in
            state.session = session
            state.mountedHydrationIndex = nil
            state.mountedNodeMap = NodeMap()
            state.mountedToLocalNodeMap = NodeMap()
            state.documentNodeIDUpperBound = request.documentNodeIDUpperBound
            state.actorBindingScope = actorBindingScope
        }
        return ClientRuntimeResponse(
            commandBatch: BrowserDOMCommandBatch(commands: []),
            hydrationIndex: hydrationIndex,
            atomicStyleRules: atomicStyleRules
        )
    }

    /// One `setProperty` per event binding, rewriting the mounted element's
    /// `data-event-*` attribute to the local render's handler id.
    private static func eventAttributeSyncCommands(
        localIndex: BrowserHydrationIndex,
        nodeMap: NodeMap
    ) -> [BrowserDOMCommand] {
        localIndex.handlers.compactMap { binding in
            guard let mountedNodeID = nodeMap[binding.nodeID] else {
                return nil
            }
            return .setProperty(
                node: mountedNodeID,
                name: HTMLRuntimeMarkers.eventAttribute(binding.eventName),
                value: binding.handlerID.rawValue
            )
        }
    }

    public func snapshotState() throws -> ClientRuntimeStateSnapshot {
        try accessGate.withExclusiveAccess {
            let schemaHash = runtimeState.withLock { state in
                state.session?.artifact.hydration.stateSchemaHash
            }
            guard let schemaHash else {
                return .empty
            }
            return try stateStore.snapshot(schemaHash: schemaHash)
        }
    }

    public func restoreState(_ snapshot: ClientRuntimeStateSnapshot) throws {
        try accessGate.withExclusiveAccess {
            let artifact = runtimeState.withLock { state in
                state.session?.artifact
            }
            guard let artifact,
                  let rebasedSnapshot = Self.rebasedSnapshot(snapshot, into: artifact)
            else {
                return
            }
            stateStore.restore(rebasedSnapshot)
        }
    }

    public func dispatch(_ request: ClientRuntimeEventRequest) throws -> ClientRuntimeResponse {
        try accessGate.withExclusiveAccess {
            let actorBindingScope = runtimeState.withLock { state in
                state.actorBindingScope
            } ?? .empty
            return try SwiftWebActorBindingContext.withValue(actorBindingScope) {
                try dispatchWithCurrentActorBindings(request)
            }
        }
    }

    private func dispatchWithCurrentActorBindings(
        _ request: ClientRuntimeEventRequest
    ) throws -> ClientRuntimeResponse {
        let state = runtimeState.withLock { state in
            (
                session: state.session,
                mountedHydrationIndex: state.mountedHydrationIndex,
                mountedNodeMap: state.mountedNodeMap,
                mountedToLocalNodeMap: state.mountedToLocalNodeMap,
                documentNodeIDUpperBound: state.documentNodeIDUpperBound
            )
        }
        guard var session = state.session else {
            throw ClientRuntimeBridgeError.notBootstrapped
        }

        // Bind a fresh transaction for this event so `withAnimation` (run inside the
        // handler) can record an animation, and read it back when applying the
        // resulting DOM changes. A new instance per event prevents leaking an
        // animation into a later, unrelated update.
        let transaction = Transaction()
        // Collect atomic CSS used while re-rendering for this event.
        let styleRegistry = StyleRegistry()
        let update = try StyleRegistry.withCurrent(styleRegistry) {
            try Transaction.$current.withValue(transaction) {
                try session.invoke(
                    handlerID: translatedHandlerID(
                        request.handlerID,
                        in: session,
                        mountedHydrationIndex: state.mountedHydrationIndex,
                        mountedToLocalNodeMap: state.mountedToLocalNodeMap
                    ),
                    event: request.event
                )
            }
        }
        let atomicStyleRules = styleRegistry.rules().map {
            ClientRuntimeAtomicStyleRule(className: $0.className, body: $0.body)
        }
        let commandBatch: BrowserDOMCommandBatch
        let hydrationIndex: BrowserHydrationIndex?
        let currentIndexForDOM: BrowserHydrationIndex
        var nextMountedHydrationIndex = state.mountedHydrationIndex
        var nextMountedNodeMap = state.mountedNodeMap
        var nextMountedToLocalNodeMap = state.mountedToLocalNodeMap
        if let componentMount {
            let mountedIndex = state.mountedHydrationIndex ?? update.hydrationIndex
            currentIndexForDOM = mountedIndex
            let previousNodeMap = state.mountedNodeMap
            let nextNodeMap = Self.structuralNodeMap(
                localIndex: update.hydrationIndex,
                mountedIndex: mountedIndex,
                mount: componentMount,
                documentNodeIDUpperBound: state.documentNodeIDUpperBound
            )
            let nextHydrationIndex = Self.rebased(
                update.hydrationIndex,
                mountedIndex: mountedIndex,
                previousNodeMap: previousNodeMap,
                nodeMap: nextNodeMap,
                mount: componentMount
            )
            let nextComponentIDMap = Self.componentIDMap(
                localIndex: update.hydrationIndex,
                mountedComponents: mountedIndex.components,
                nodeMap: nextNodeMap
            )
            let nextServerSlotIDMap = Self.serverSlotIDMap(
                localIndex: update.hydrationIndex,
                mountedServerSlots: mountedIndex.serverSlots,
                nodeMap: nextNodeMap
            )
            commandBatch = Self.rebased(
                update.commandBatch,
                previousNodeMap: previousNodeMap,
                nextNodeMap: nextNodeMap,
                componentIDMap: nextComponentIDMap,
                serverSlotIDMap: nextServerSlotIDMap
            )
            hydrationIndex = nextHydrationIndex
            nextMountedNodeMap = nextNodeMap
            nextMountedToLocalNodeMap = nextNodeMap.inverted()
            nextMountedHydrationIndex = nextHydrationIndex
        } else {
            commandBatch = update.commandBatch
            hydrationIndex = update.hydrationIndex
            currentIndexForDOM = update.previousHydrationIndex
        }

        if let domHost {
            try domHost.apply(
                commandBatch,
                currentIndex: currentIndexForDOM,
                animation: transaction.animation
            )
        }
        runtimeState.withLock { state in
            state.session = session
            state.mountedHydrationIndex = nextMountedHydrationIndex
            state.mountedNodeMap = nextMountedNodeMap
            state.mountedToLocalNodeMap = nextMountedToLocalNodeMap
        }
        return ClientRuntimeResponse(
            commandBatch: commandBatch,
            hydrationIndex: hydrationIndex,
            atomicStyleRules: atomicStyleRules,
            appliesDOMCommandsInRuntime: domHost != nil
        )
    }

    private static func defaultActorSystem() -> WebActorSystem {
        #if os(WASI)
        WebActorSystem(transport: JavaScriptKitWebActorTransport())
        #else
        WebActorSystem.shared
        #endif
    }

    private func makeSession(
        root: Root,
        environment: EnvironmentValues,
        options: HTMLRenderOptions,
        restoring snapshot: ClientRuntimeStateSnapshot?
    ) throws -> HydrationRuntimeSession<Root> {
        var nextSession = try HydrationRuntimeSession(
            root: root,
            environment: environment,
            stateStore: stateStore,
            options: options
        )
        guard let snapshot,
              let rebasedSnapshot = Self.rebasedSnapshot(snapshot, into: nextSession.artifact)
        else {
            return nextSession
        }

        stateStore.restore(rebasedSnapshot)
        nextSession = try HydrationRuntimeSession(
            root: root,
            environment: environment,
            stateStore: stateStore,
            options: options
        )
        return nextSession
    }

    private func translatedHandlerID(
        _ mountedHandlerID: HandlerID,
        in session: HydrationRuntimeSession<Root>,
        mountedHydrationIndex: BrowserHydrationIndex?,
        mountedToLocalNodeMap: NodeMap
    ) -> HandlerID {
        let localIndex = session.artifact.browserHydrationIndex()
        if componentMount != nil,
           let mountedHydrationIndex,
           let mountedBinding = mountedHydrationIndex.handlers.first(where: { binding in
               binding.handlerID == mountedHandlerID
           }) {
            if let localNodeID = mountedToLocalNodeMap[mountedBinding.nodeID],
               let localBinding = localIndex.handlers.first(where: { binding in
                   binding.nodeID == localNodeID
                       && binding.eventName == mountedBinding.eventName
               }) {
                return localBinding.handlerID
            }
        }

        // The DOM's event attributes are normalized to the local id space at
        // bootstrap and kept in sync by the attribute diff. IDs outside the
        // mounted subtree therefore resolve directly in the local artifact.
        return mountedHandlerID
    }

    private static func canRestore(
        _ snapshot: ClientRuntimeStateSnapshot,
        into artifact: RenderArtifact
    ) -> Bool {
        snapshot.schemaHash == artifact.hydration.stateSchemaHash
    }

    private static func rebasedSnapshot(
        _ snapshot: ClientRuntimeStateSnapshot,
        into artifact: RenderArtifact
    ) -> ClientRuntimeStateSnapshot? {
        if canRestore(snapshot, into: artifact) {
            return snapshot
        }

        let slotsByStableKey = Dictionary(grouping: artifact.hydration.stateSchema.slots) { slot in
            stableStateSlotKey(source: slot.source.rawValue, valueType: slot.valueType)
        }
        guard !slotsByStableKey.isEmpty else {
            return nil
        }

        let snapshotValuesByStableKey = Dictionary(grouping: snapshot.values) { key, value in
            stableStateSlotKey(source: stateSourceRawValue(from: key), valueType: value.valueType)
        }
        var values: [String: StateSnapshotValue] = [:]
        for (stableKey, slots) in slotsByStableKey {
            guard let snapshotValues = snapshotValuesByStableKey[stableKey] else {
                continue
            }
            let orderedSlots = slots.sorted { left, right in
                left.id.rawValue < right.id.rawValue
            }
            let orderedValues = snapshotValues.sorted { left, right in
                left.key < right.key
            }
            for (slot, snapshotValue) in zip(orderedSlots, orderedValues) {
                values[slot.id.rawValue] = snapshotValue.value
            }
        }

        guard !values.isEmpty || snapshot.values.isEmpty else {
            return nil
        }
        return StateStoreSnapshot(
            schemaHash: artifact.hydration.stateSchemaHash,
            values: values
        )
    }

    private static func stateSourceRawValue(from stateSlotID: String) -> String {
        guard let range = stateSlotID.firstRange(of: ":state:") else {
            return stateSlotID
        }
        return String(stateSlotID[range.upperBound...])
    }

    private static func stableStateSlotKey(source: String, valueType: String) -> String {
        "\(source)|\(valueType)"
    }

    private static func nodeMap(
        localIndex: BrowserHydrationIndex,
        mountedIndex: BrowserHydrationIndex,
        mount: ClientComponentMount
    ) throws -> NodeMap {
        guard let localComponent = Self.component(in: localIndex, matching: mount) else {
            throw ClientRuntimeBridgeError.componentMountNotFound(mount.typeName)
        }
        guard let mountedComponent = Self.component(in: mountedIndex, matching: mount) else {
            throw ClientRuntimeBridgeError.componentMountNotFound(mount.typeName)
        }

        var map = NodeMap()
        buildNodeMap(
            localID: localComponent.nodeID,
            mountedID: mountedComponent.nodeID,
            localIndex: localIndex,
            mountedIndex: mountedIndex,
            into: &map
        )
        return map
    }

    private static func hotReloadCommandBatch(
        localArtifact: RenderArtifact?,
        localIndex: BrowserHydrationIndex,
        mountedIndex: BrowserHydrationIndex,
        nodeMap: NodeMap,
        mount: ClientComponentMount
    ) -> BrowserDOMCommandBatch {
        guard let localArtifact,
              let localComponent = Self.component(in: localIndex, matching: mount),
              let mountedComponent = Self.component(in: mountedIndex, matching: mount),
              let mountedRoot = nodeMap[localComponent.nodeID],
              mountedRoot == mountedComponent.nodeID
        else {
            return BrowserDOMCommandBatch(commands: [])
        }

        var commands: [BrowserDOMCommand] = []
        let mountedToLocal = nodeMap.inverted()
        let componentIDMap = componentIDMap(
            localIndex: localIndex,
            mountedComponents: mountedIndex.components,
            nodeMap: nodeMap
        )
        let serverSlotIDMap = serverSlotIDMap(
            localIndex: localIndex,
            mountedServerSlots: mountedIndex.serverSlots,
            nodeMap: nodeMap
        )
        appendHotReloadCommands(
            localID: localComponent.nodeID,
            mountedID: mountedComponent.nodeID,
            localArtifact: localArtifact,
            localIndex: localIndex,
            mountedIndex: mountedIndex,
            localToMounted: nodeMap,
            mountedToLocal: mountedToLocal,
            componentIDMap: componentIDMap,
            serverSlotIDMap: serverSlotIDMap,
            commands: &commands
        )
        return BrowserDOMCommandBatch(commands: commands)
    }

    private static func component(
        in index: BrowserHydrationIndex,
        matching mount: ClientComponentMount
    ) -> BrowserHydrationComponentRecord? {
        if let componentID = mount.componentID,
           let component = index.component(componentID) {
            return component
        }
        return index.components.first { component in
            component.typeName == mount.typeName
        }
    }

    private static func appendHotReloadCommands(
        localID: HTMLNodeID,
        mountedID: HTMLNodeID,
        localArtifact: RenderArtifact,
        localIndex: BrowserHydrationIndex,
        mountedIndex: BrowserHydrationIndex,
        localToMounted: NodeMap,
        mountedToLocal: NodeMap,
        componentIDMap: ComponentIDMap,
        serverSlotIDMap: ServerSlotIDMap,
        commands: inout [BrowserDOMCommand]
    ) {
        guard let localNode = localIndex.node(localID),
              let mountedNode = mountedIndex.node(mountedID)
        else {
            return
        }

        guard nodesAreCompatible(localNode, mountedNode) else {
            commands.append(.replaceSubtree(
                node: mountedID,
                html: renderRebasedSubtree(
                    localArtifact,
                    node: localID,
                    nodeMap: localToMounted,
                    componentIDMap: componentIDMap,
                    serverSlotIDMap: serverSlotIDMap
                )
            ))
            return
        }

        switch localNode.role {
        case .text, .rawHTML, .placeholder:
            if localNode.text != mountedNode.text {
                commands.append(.updateText(node: mountedID, value: localNode.text ?? ""))
            }
            return
        case .comment:
            if localNode.text != mountedNode.text {
                commands.append(.updateComment(node: mountedID, value: localNode.text ?? ""))
            }
            return
        case .element:
            if localNode.attributes != mountedNode.attributes {
                commands.append(.updateAttributes(node: mountedID, attributes: localNode.attributes))
                appendPropertyCommands(
                    node: mountedID,
                    oldAttributes: mountedNode.attributes,
                    newAttributes: localNode.attributes,
                    commands: &commands
                )
            }
        case .document, .doctype, .fragment, .component, .serverSlot:
            break
        }

        appendHotReloadChildCommands(
            localNode: localNode,
            mountedNode: mountedNode,
            localArtifact: localArtifact,
            localIndex: localIndex,
            mountedIndex: mountedIndex,
            localToMounted: localToMounted,
            mountedToLocal: mountedToLocal,
            componentIDMap: componentIDMap,
            serverSlotIDMap: serverSlotIDMap,
            commands: &commands
        )
    }

    private static func appendHotReloadChildCommands(
        localNode: BrowserHydrationNodeRecord,
        mountedNode: BrowserHydrationNodeRecord,
        localArtifact: RenderArtifact,
        localIndex: BrowserHydrationIndex,
        mountedIndex: BrowserHydrationIndex,
        localToMounted: NodeMap,
        mountedToLocal: NodeMap,
        componentIDMap: ComponentIDMap,
        serverSlotIDMap: ServerSlotIDMap,
        commands: inout [BrowserDOMCommand]
    ) {
        var mountedPositions = NodePositionMap()
        for (index, childID) in mountedNode.childIDs.enumerated() {
            mountedPositions[childID] = index
        }

        for (index, mountedChildID) in mountedNode.childIDs.enumerated().reversed() {
            if mountedToLocal[mountedChildID] == nil {
                commands.append(.remove(parent: mountedNode.id, index: index, node: mountedChildID))
            }
        }

        for (index, localChildID) in localNode.childIDs.enumerated() {
            guard let mountedChildID = localToMounted[localChildID],
                  mountedIndex.node(mountedChildID) != nil
            else {
                commands.append(.insertHTML(
                    parent: mountedNode.id,
                    index: index,
                    html: renderRebasedSubtree(
                        localArtifact,
                        node: localChildID,
                        nodeMap: localToMounted,
                        componentIDMap: componentIDMap,
                        serverSlotIDMap: serverSlotIDMap
                    )
                ))
                continue
            }

            appendHotReloadCommands(
                localID: localChildID,
                mountedID: mountedChildID,
                localArtifact: localArtifact,
                localIndex: localIndex,
                mountedIndex: mountedIndex,
                localToMounted: localToMounted,
                mountedToLocal: mountedToLocal,
                componentIDMap: componentIDMap,
                serverSlotIDMap: serverSlotIDMap,
                commands: &commands
            )

            guard let mountedIndex = mountedPositions[mountedChildID],
                  mountedIndex != index
            else {
                continue
            }

            if let key = localIndex.node(localChildID)?.key {
                commands.append(.moveKeyed(parent: mountedNode.id, key: key, to: index))
            } else {
                commands.append(.move(parent: mountedNode.id, from: mountedIndex, to: index, key: Key(index)))
            }
        }
    }

    private static func appendPropertyCommands(
        node: HTMLNodeID,
        oldAttributes: [HTMLAttributeRecord],
        newAttributes: [HTMLAttributeRecord],
        commands: inout [BrowserDOMCommand]
    ) {
        let oldProperties = Dictionary(
            uniqueKeysWithValues: oldAttributes
                .filter { $0.kind == .propertyBinding }
                .map { ($0.name, $0.value) }
        )
        let newProperties = Dictionary(
            uniqueKeysWithValues: newAttributes
                .filter { $0.kind == .propertyBinding }
                .map { ($0.name, $0.value) }
        )
        for name in Set(oldProperties.keys).union(newProperties.keys).sorted()
            where oldProperties[name] != newProperties[name] {
            commands.append(.setProperty(node: node, name: name, value: newProperties[name] ?? nil))
        }
    }

    private static func buildNodeMap(
        localID: HTMLNodeID,
        mountedID: HTMLNodeID,
        localIndex: BrowserHydrationIndex,
        mountedIndex: BrowserHydrationIndex,
        into map: inout NodeMap
    ) {
        guard
            let localNode = localIndex.node(localID),
            let mountedNode = mountedIndex.node(mountedID)
        else {
            return
        }

        map[localID] = mountedID

        for (localChildID, mountedChildID) in zip(localNode.childIDs, mountedNode.childIDs) {
            buildNodeMap(
                localID: localChildID,
                mountedID: mountedChildID,
                localIndex: localIndex,
                mountedIndex: mountedIndex,
                into: &map
            )
        }
    }

    private static func rebased(
        _ batch: BrowserDOMCommandBatch,
        previousNodeMap: NodeMap,
        nextNodeMap: NodeMap,
        componentIDMap: ComponentIDMap,
        serverSlotIDMap: ServerSlotIDMap
    ) -> BrowserDOMCommandBatch {
        BrowserDOMCommandBatch(commands: batch.commands.compactMap { command in
            rebased(
                command,
                previousNodeMap: previousNodeMap,
                nextNodeMap: nextNodeMap,
                componentIDMap: componentIDMap,
                serverSlotIDMap: serverSlotIDMap
            )
        })
    }

    private static func rebased(
        _ command: BrowserDOMCommand,
        previousNodeMap: NodeMap,
        nextNodeMap: NodeMap,
        componentIDMap: ComponentIDMap,
        serverSlotIDMap: ServerSlotIDMap
    ) -> BrowserDOMCommand? {
        func previousNode(_ id: HTMLNodeID) -> HTMLNodeID? {
            previousNodeMap[id]
        }

        func nextNode(_ id: HTMLNodeID) -> HTMLNodeID? {
            nextNodeMap[id]
        }

        switch command {
        case .replaceNode(let nodeID, let replacementID):
            guard let mappedNode = previousNode(nodeID), let mappedReplacement = nextNode(replacementID) else {
                return nil
            }
            return .replaceNode(node: mappedNode, replacement: mappedReplacement)
        case .replaceSubtree(let nodeID, let html):
            guard let mappedNode = previousNode(nodeID) else {
                return nil
            }
            return .replaceSubtree(
                node: mappedNode,
                html: rebaseHydrationMarkers(
                    in: html,
                    nodeMap: nextNodeMap,
                    componentIDMap: componentIDMap,
                    serverSlotIDMap: serverSlotIDMap
                )
            )
        case .updateText(let nodeID, let value):
            guard let mappedNode = previousNode(nodeID) else {
                return nil
            }
            return .updateText(node: mappedNode, value: value)
        case .updateComment(let nodeID, let value):
            guard let mappedNode = previousNode(nodeID) else {
                return nil
            }
            return .updateComment(node: mappedNode, value: value)
        case .updateAttributes(let nodeID, let attributes):
            guard let mappedNode = previousNode(nodeID) else {
                return nil
            }
            return .updateAttributes(node: mappedNode, attributes: attributes)
        case .setProperty(let nodeID, let name, let value):
            guard let mappedNode = previousNode(nodeID) else {
                return nil
            }
            return .setProperty(node: mappedNode, name: name, value: value)
        case .insertNode(let parentID, let index, let nodeID):
            guard let mappedParent = previousNode(parentID), let mappedNode = nextNode(nodeID) else {
                return nil
            }
            return .insertNode(parent: mappedParent, index: index, node: mappedNode)
        case .insertHTML(let parentID, let index, let html):
            guard let mappedParent = previousNode(parentID) else {
                return nil
            }
            return .insertHTML(
                parent: mappedParent,
                index: index,
                html: rebaseHydrationMarkers(
                    in: html,
                    nodeMap: nextNodeMap,
                    componentIDMap: componentIDMap,
                    serverSlotIDMap: serverSlotIDMap
                )
            )
        case .remove(let parentID, let index, let nodeID):
            guard let mappedParent = previousNode(parentID), let mappedNode = previousNode(nodeID) else {
                return nil
            }
            return .remove(parent: mappedParent, index: index, node: mappedNode)
        case .move(let parentID, let from, let to, let key):
            guard let mappedParent = previousNode(parentID) else {
                return nil
            }
            return .move(parent: mappedParent, from: from, to: to, key: key)
        case .moveKeyed(let parentID, let key, let to):
            guard let mappedParent = previousNode(parentID) else {
                return nil
            }
            return .moveKeyed(parent: mappedParent, key: key, to: to)
        }
    }

    private static func structuralNodeMap(
        localIndex: BrowserHydrationIndex,
        mountedIndex: BrowserHydrationIndex,
        mount: ClientComponentMount,
        documentNodeIDUpperBound: Int?
    ) -> NodeMap {
        guard let localComponent = component(in: localIndex, matching: mount),
              let mountedComponent = component(in: mountedIndex, matching: mount) else {
            return NodeMap()
        }

        var map = NodeMap()
        var allocatedMountedIDs = NodeIDSet(mountedIndex.nodes.map { $0.id })
        var nextNodeID = max(
            mountedIndex.nodes.map { $0.id.rawValue }.max() ?? -1,
            documentNodeIDUpperBound ?? -1
        ) + 1

        func allocateMountedID() -> HTMLNodeID {
            while allocatedMountedIDs.contains(HTMLNodeID(nextNodeID)) {
                nextNodeID += 1
            }
            let id = HTMLNodeID(nextNodeID)
            allocatedMountedIDs.insert(id)
            nextNodeID += 1
            return id
        }

        func walk(localID: HTMLNodeID, mountedID: HTMLNodeID?) {
            let mappedID = mountedID ?? allocateMountedID()
            map[localID] = mappedID

            guard let localNode = localIndex.node(localID) else {
                return
            }
            let mountedNode = mappedID == mountedID ? mountedIndex.node(mappedID) : nil
            let childMatches = matchedChildren(
                localChildren: localNode.childIDs,
                mountedChildren: mountedNode?.childIDs ?? [],
                localIndex: localIndex,
                mountedIndex: mountedIndex
            )
            for localChildID in localNode.childIDs {
                walk(localID: localChildID, mountedID: childMatches[localChildID])
            }
        }

        walk(localID: localComponent.nodeID, mountedID: mountedComponent.nodeID)
        return map
    }

    private static func boundaryNodeMap(
        mountedIndex: BrowserHydrationIndex,
        mount: ClientComponentMount
    ) -> NodeMap {
        guard let mountedComponent = component(in: mountedIndex, matching: mount) else {
            return NodeMap()
        }

        var map = NodeMap()
        func walk(_ mountedID: HTMLNodeID) {
            map[mountedID] = mountedID
            guard let mountedNode = mountedIndex.node(mountedID) else {
                return
            }
            for childID in mountedNode.childIDs {
                walk(childID)
            }
        }
        walk(mountedComponent.nodeID)
        return map
    }

    private static func matchedChildren(
        localChildren: [HTMLNodeID],
        mountedChildren: [HTMLNodeID],
        localIndex: BrowserHydrationIndex,
        mountedIndex: BrowserHydrationIndex
    ) -> NodeMap {
        var matches = NodeMap()
        var usedMountedIDs = NodeIDSet()
        let mountedKeyedChildren = MountedKeyedChildIndex(
            childIDs: mountedChildren,
            index: mountedIndex
        )

        for localID in localChildren {
            guard let localNode = localIndex.node(localID), let key = localNode.key else {
                continue
            }
            if let mountedID = mountedKeyedChildren.nodeID(
                for: key,
                compatibleWith: localNode,
                excluding: usedMountedIDs
            ) {
                matches[localID] = mountedID
                usedMountedIDs.insert(mountedID)
            }
        }

        let localStableSignatures = stableDOMSignatures(
            for: localChildren,
            in: localIndex,
            excluding: NodeIDSet(matches.keys)
        )
        let mountedStableSignatures = stableDOMSignatures(
            for: mountedChildren,
            in: mountedIndex,
            excluding: usedMountedIDs
        )
        for localID in localChildren where matches[localID] == nil {
            guard let signature = localStableSignatures.signature(for: localID),
                  let mountedID = mountedStableSignatures.nodeID(for: signature),
                  !usedMountedIDs.contains(mountedID),
                  let localNode = localIndex.node(localID),
                  let mountedNode = mountedIndex.node(mountedID),
                  nodesAreCompatible(localNode, mountedNode)
            else {
                continue
            }
            matches[localID] = mountedID
            usedMountedIDs.insert(mountedID)
        }

        // Keyed children whose keys did not line up (the rendered data changed
        // between the mounted render and this one — e.g. a calendar grid whose
        // per-day keys all move on a month change) still need a DOM anchor:
        // pair the remaining keyed locals with the remaining keyed mounted
        // children in order. Without this pass an unmatched keyed child is
        // assigned a synthetic node id that resolves to no DOM element, so its
        // patches are silently dropped and the keyed wrapper vanishes from the
        // DOM on re-render.
        var keyedCursor = 0
        for localID in localChildren where matches[localID] == nil {
            guard let localNode = localIndex.node(localID), localNode.key != nil else {
                continue
            }
            while keyedCursor < mountedChildren.count {
                let mountedID = mountedChildren[keyedCursor]
                keyedCursor += 1
                guard !usedMountedIDs.contains(mountedID),
                      let mountedNode = mountedIndex.node(mountedID),
                      mountedNode.key != nil,
                      nodesAreCompatible(localNode, mountedNode) else {
                    continue
                }
                matches[localID] = mountedID
                usedMountedIDs.insert(mountedID)
                break
            }
        }

        var mountedCursor = 0
        for localID in localChildren where matches[localID] == nil {
            guard let localNode = localIndex.node(localID), localNode.key == nil else {
                continue
            }
            while mountedCursor < mountedChildren.count {
                let mountedID = mountedChildren[mountedCursor]
                mountedCursor += 1
                guard !usedMountedIDs.contains(mountedID),
                      let mountedNode = mountedIndex.node(mountedID),
                      mountedNode.key == nil,
                      nodesAreCompatible(localNode, mountedNode) else {
                    continue
                }
                matches[localID] = mountedID
                usedMountedIDs.insert(mountedID)
                break
            }
        }

        return matches
    }

    private static func stableDOMSignatures(
        for childIDs: [HTMLNodeID],
        in index: BrowserHydrationIndex,
        excluding excludedIDs: NodeIDSet
    ) -> StableDOMSignatureIndex {
        var records: [StableDOMSignatureRecord] = []

        for childID in childIDs where !excludedIDs.contains(childID) {
            guard let node = index.node(childID),
                  let signature = stableDOMSignature(for: node)
            else {
                continue
            }
            records.append(StableDOMSignatureRecord(nodeID: childID, signature: signature))
        }

        let sortedBySignature = records.sorted { left, right in
            left.signature < right.signature
        }
        var uniqueRecords: [StableDOMSignatureRecord] = []
        var cursor = 0
        while cursor < sortedBySignature.count {
            let signature = sortedBySignature[cursor].signature
            var next = cursor + 1
            while next < sortedBySignature.count,
                  sortedBySignature[next].signature == signature {
                next += 1
            }
            if next == cursor + 1 {
                uniqueRecords.append(sortedBySignature[cursor])
            }
            cursor = next
        }
        return StableDOMSignatureIndex(uniqueRecords)
    }

    private static func stableDOMSignature(for node: BrowserHydrationNodeRecord) -> String? {
        guard node.role == .element,
              let name = node.name
        else {
            return nil
        }

        var eventNames: [String] = []
        for binding in node.eventBindings {
            eventNames.append(binding.eventName)
        }
        eventNames.sort()
        var propertyNames: [String] = []
        for attribute in node.attributes where attribute.kind == .propertyBinding {
            propertyNames.append(attribute.name)
        }
        propertyNames.sort()
        guard !eventNames.isEmpty || !propertyNames.isEmpty else {
            return nil
        }

        return [
            name,
            eventNames.joined(separator: ","),
            propertyNames.joined(separator: ","),
        ].joined(separator: "|")
    }

    private static func nodesAreCompatible(
        _ localNode: BrowserHydrationNodeRecord,
        _ mountedNode: BrowserHydrationNodeRecord
    ) -> Bool {
        localNode.role == mountedNode.role
            && localNode.name == mountedNode.name
            && (localNode.componentID != nil) == (mountedNode.componentID != nil)
            && (localNode.serverSlotID != nil) == (mountedNode.serverSlotID != nil)
    }

    private static func rebased(
        _ localIndex: BrowserHydrationIndex,
        mountedIndex: BrowserHydrationIndex,
        previousNodeMap: NodeMap,
        nodeMap: NodeMap,
        mount: ClientComponentMount
    ) -> BrowserHydrationIndex {
        let previousMountedNodes = previousMountedSubtreeNodeIDs(
            localIndex: localIndex,
            mountedIndex: mountedIndex,
            previousNodeMap: previousNodeMap,
            mount: mount
        )
        let componentIDMap = componentIDMap(
            localIndex: localIndex,
            mountedComponents: mountedIndex.components,
            nodeMap: nodeMap
        )
        let mountedComponentIndex = MountedComponentByNodeIndex(mountedIndex.components)
        let mountedHandlerIndex = MountedHandlerIndex(mountedIndex.handlers)
        let outsideNodes = mountedIndex.nodes.filter { node in
            !previousMountedNodes.contains(node.id)
        }
        let rebasedNodes = localIndex.nodes.compactMap { node in
            rebased(
                node,
                nodeMap: nodeMap,
                componentIDMap: componentIDMap,
                mountedIndex: mountedIndex,
                mountedHandlerIndex: mountedHandlerIndex
            )
        }
        let outsideComponents = mountedIndex.components.filter { component in
            !previousMountedNodes.contains(component.nodeID)
        }
        let rebasedComponents = localIndex.components.compactMap { component in
            rebased(
                component,
                nodeMap: nodeMap,
                componentIDMap: componentIDMap,
                mountedComponentIndex: mountedComponentIndex
            )
        }
        let outsideServerSlots = mountedIndex.serverSlots.filter { slot in
            !previousMountedNodes.contains(slot.nodeID)
        }
        let rebasedServerSlots = localIndex.serverSlots.compactMap { slot in
            rebased(slot, nodeMap: nodeMap, componentIDMap: componentIDMap)
        }
        let outsideHandlers = mountedIndex.handlers.filter { binding in
            !previousMountedNodes.contains(binding.nodeID)
        }
        let rebasedHandlers = localIndex.handlers.compactMap { binding in
            rebaseEventBinding(
                binding,
                nodeMap: nodeMap,
                componentIDMap: componentIDMap,
                mountedHandlerIndex: mountedHandlerIndex
            )
        }

        return BrowserHydrationIndex(
            rootID: mountedIndex.rootID,
            nodes: (outsideNodes + rebasedNodes).sorted { $0.id.rawValue < $1.id.rawValue },
            components: (outsideComponents + rebasedComponents).sorted { $0.path < $1.path },
            serverSlots: (outsideServerSlots + rebasedServerSlots).sorted { $0.id.rawValue < $1.id.rawValue },
            handlers: (outsideHandlers + rebasedHandlers).sorted { $0.handlerID.rawValue < $1.handlerID.rawValue }
        )
    }

    private static func previousMountedSubtreeNodeIDs(
        localIndex: BrowserHydrationIndex,
        mountedIndex: BrowserHydrationIndex,
        previousNodeMap: NodeMap,
        mount: ClientComponentMount
    ) -> NodeIDSet {
        // The subtree to replace must be located on the MOUNTED side (the
        // component's record in the previous full-page index). Looking up a
        // fresh local node ID in the previous node map is wrong: node IDs are
        // render-local, so after a structural change the new root's ID can be
        // reused by an unrelated previous node, the walk then excludes the
        // wrong subtree, and the whole previous component survives alongside
        // its rebased copy — duplicate node and component IDs that kill every
        // later `Dictionary(uniqueKeysWithValues:)` over the index.
        guard let mountedComponentNodeID = component(in: mountedIndex, matching: mount)?.nodeID else {
            return NodeIDSet(previousNodeMap.values)
        }

        var ids = NodeIDSet()
        func walk(_ nodeID: HTMLNodeID) {
            guard ids.insert(nodeID),
                  let node = mountedIndex.node(nodeID)
            else {
                return
            }
            for childID in node.childIDs {
                walk(childID)
            }
        }
        walk(mountedComponentNodeID)
        return ids
    }

    private static func componentIDMap(
        localIndex: BrowserHydrationIndex,
        mountedComponents: [BrowserHydrationComponentRecord],
        nodeMap: NodeMap
    ) -> ComponentIDMap {
        var map = ComponentIDMap()
        let mountedIndex = MountedComponentByNodeIndex(mountedComponents)
        for component in localIndex.components {
            if let mountedNodeID = nodeMap[component.nodeID],
               let mountedComponent = mountedIndex.record(for: mountedNodeID) {
                map.appendUnsorted(mountedComponent.id, for: component.id)
            } else {
                map.appendUnsorted(component.id, for: component.id)
            }
        }
        map.prepareForLookup()
        return map
    }

    private static func serverSlotIDMap(
        localIndex: BrowserHydrationIndex,
        mountedServerSlots: [ServerSlotRecord],
        nodeMap: NodeMap
    ) -> ServerSlotIDMap {
        var map = ServerSlotIDMap()
        let mountedIndex = MountedServerSlotByNodeIndex(mountedServerSlots)
        for slot in localIndex.serverSlots {
            if let mountedNodeID = nodeMap[slot.nodeID],
               let mountedSlot = mountedIndex.record(for: mountedNodeID) {
                map.appendUnsorted(mountedSlot.id, for: slot.id)
            } else {
                map.appendUnsorted(slot.id, for: slot.id)
            }
        }
        map.prepareForLookup()
        return map
    }

    private static func renderRebasedSubtree(
        _ artifact: RenderArtifact,
        node: HTMLNodeID,
        nodeMap: NodeMap,
        componentIDMap: ComponentIDMap,
        serverSlotIDMap: ServerSlotIDMap
    ) -> String {
        rebaseHydrationMarkers(
            in: artifact.renderSubtree(node, options: .development.withBrowserHydrationMarkers()),
            nodeMap: nodeMap,
            componentIDMap: componentIDMap,
            serverSlotIDMap: serverSlotIDMap
        )
    }

    private static func rebaseHydrationMarkers(
        in html: String,
        nodeMap: NodeMap,
        componentIDMap: ComponentIDMap,
        serverSlotIDMap: ServerSlotIDMap
    ) -> String {
        rebaseBoundaryCommentMarkers(
            in: rebaseNodeMarkers(in: html, nodeMap: nodeMap),
            componentIDMap: componentIDMap,
            serverSlotIDMap: serverSlotIDMap
        )
    }

    private static func rebaseBoundaryCommentMarkers(
        in html: String,
        componentIDMap: ComponentIDMap,
        serverSlotIDMap: ServerSlotIDMap
    ) -> String {
        let openingMarker = "<!--"
        let closingMarker = "-->"
        var output = ""
        output.reserveCapacity(html.utf8.count)
        var cursor = html.startIndex

        while let openingRange = html[cursor...].firstRange(of: openingMarker) {
            output.append(contentsOf: html[cursor..<openingRange.lowerBound])
            guard let closingRange = html[openingRange.upperBound...].firstRange(of: closingMarker) else {
                output.append(contentsOf: html[openingRange.lowerBound...])
                return output
            }

            let value = html[openingRange.upperBound..<closingRange.lowerBound]
            let fields = value.split(separator: ":", omittingEmptySubsequences: false)
            if fields.count == 3,
               let edge = HTMLRuntimeMarkers.BoundaryEdge(rawValue: String(fields[2])) {
                let rawID = String(fields[1])
                switch fields[0] {
                case Substring(HTMLRuntimeMarkers.componentCommentPrefix):
                    let source = ComponentID(rawID)
                    let target = componentIDMap[source] ?? source
                    output.append("<!--")
                    output.append(HTMLRuntimeMarkers.componentCommentValue(target, edge: edge))
                    output.append("-->")
                case Substring(HTMLRuntimeMarkers.serverSlotCommentPrefix):
                    let source = ServerSlotID(rawID)
                    let target = serverSlotIDMap[source] ?? source
                    output.append("<!--")
                    output.append(HTMLRuntimeMarkers.serverSlotCommentValue(target, edge: edge))
                    output.append("-->")
                default:
                    output.append(contentsOf: html[openingRange.lowerBound..<closingRange.upperBound])
                }
            } else {
                output.append(contentsOf: html[openingRange.lowerBound..<closingRange.upperBound])
            }
            cursor = closingRange.upperBound
        }

        output.append(contentsOf: html[cursor...])
        return output
    }

    private static func rebaseNodeMarkers(
        in html: String,
        nodeMap: NodeMap
    ) -> String {
        let marker = "\(HTMLRuntimeMarkers.nodeAttribute)=\""
        var output = ""
        var cursor = html.startIndex

        while let range = html[cursor...].firstRange(of: marker) {
            output.append(contentsOf: html[cursor..<range.upperBound])
            var numberEnd = range.upperBound
            while numberEnd < html.endIndex, html[numberEnd].isNumber {
                numberEnd = html.index(after: numberEnd)
            }

            let rawValue = String(html[range.upperBound..<numberEnd])
            if numberEnd < html.endIndex,
               html[numberEnd] == "\"",
               let value = Int(rawValue),
               let mapped = nodeMap[HTMLNodeID(value)] {
                output.append(String(mapped.rawValue))
            } else {
                output.append(rawValue)
            }
            cursor = numberEnd
        }

        output.append(contentsOf: html[cursor...])
        return output
    }

    private static func rebased(
        _ node: BrowserHydrationNodeRecord,
        nodeMap: NodeMap,
        componentIDMap: ComponentIDMap,
        mountedIndex: BrowserHydrationIndex,
        mountedHandlerIndex: MountedHandlerIndex
    ) -> BrowserHydrationNodeRecord? {
        guard let mappedID = nodeMap[node.id] else {
            return nil
        }
        let mountedNode = mountedIndex.node(mappedID)
        let parentID = node.parentID.flatMap { nodeMap[$0] } ?? mountedNode?.parentID
        return BrowserHydrationNodeRecord(
            id: mappedID,
            parentID: parentID,
            childIDs: node.childIDs.compactMap { nodeMap[$0] },
            role: node.role,
            name: node.name,
            text: node.text,
            componentID: node.componentID.flatMap { componentIDMap[$0] },
            serverSlotID: node.serverSlotID,
            attributes: node.attributes,
            eventBindings: node.eventBindings.compactMap {
                rebaseEventBinding(
                    $0,
                    nodeMap: nodeMap,
                    componentIDMap: componentIDMap,
                    mountedHandlerIndex: mountedHandlerIndex
                )
            },
            key: node.key,
            fingerprint: node.fingerprint
        )
    }

    private static func rebased(
        _ component: BrowserHydrationComponentRecord,
        nodeMap: NodeMap,
        componentIDMap: ComponentIDMap,
        mountedComponentIndex: MountedComponentByNodeIndex
    ) -> BrowserHydrationComponentRecord? {
        guard let mappedNodeID = nodeMap[component.nodeID] else {
            return nil
        }
        if let mountedComponent = mountedComponentIndex.record(for: mappedNodeID) {
            return BrowserHydrationComponentRecord(
                id: mountedComponent.id,
                typeName: mountedComponent.typeName,
                path: mountedComponent.path,
                nodeID: mappedNodeID,
                bundleID: mountedComponent.bundleID,
                loadPolicy: mountedComponent.loadPolicy,
                serverSlotIDs: mountedComponent.serverSlotIDs,
                stateSlots: mountedComponent.stateSlots,
                environmentSnapshot: mountedComponent.environmentSnapshot
            )
        }
        return BrowserHydrationComponentRecord(
            id: componentIDMap[component.id] ?? component.id,
            typeName: component.typeName,
            path: component.path,
            nodeID: mappedNodeID,
            bundleID: component.bundleID,
            loadPolicy: component.loadPolicy,
            serverSlotIDs: component.serverSlotIDs,
            stateSlots: component.stateSlots,
            environmentSnapshot: component.environmentSnapshot
        )
    }

    private static func rebased(
        _ slot: ServerSlotRecord,
        nodeMap: NodeMap,
        componentIDMap: ComponentIDMap
    ) -> ServerSlotRecord? {
        guard let mappedNodeID = nodeMap[slot.nodeID] else {
            return nil
        }
        return ServerSlotRecord(
            id: slot.id,
            ownerComponentID: componentIDMap[slot.ownerComponentID] ?? slot.ownerComponentID,
            componentType: slot.componentType,
            path: slot.path,
            nodeID: mappedNodeID
        )
    }

    private static func rebaseEventBinding(
        _ binding: BrowserHydrationEventBinding,
        nodeMap: NodeMap,
        componentIDMap: ComponentIDMap,
        mountedHandlerIndex: MountedHandlerIndex
    ) -> BrowserHydrationEventBinding? {
        guard let mappedNodeID = nodeMap[binding.nodeID] else {
            return nil
        }
        let mountedHandlerID = mountedHandlerIndex.handlerID(
            for: mappedNodeID,
            eventName: binding.eventName
        )

        // Keep an existing mounted handler's stable public identity. The DOM
        // carries local handler IDs after bootstrap normalization, while
        // `translatedHandlerID` accepts either space by matching node and
        // event name before considering a raw ID match.
        return BrowserHydrationEventBinding(
            nodeID: mappedNodeID,
            handlerID: mountedHandlerID ?? binding.handlerID,
            eventName: binding.eventName,
            componentID: binding.componentID.flatMap { componentIDMap[$0] }
        )
    }
}

public extension ClientEnvironmentRegistry {
    func componentEnvironments(
        from index: BrowserHydrationIndex,
        base: EnvironmentValues = EnvironmentValues()
    ) throws -> [String: EnvironmentValues] {
        var environments: [String: EnvironmentValues] = [:]
        let components = index.components.sorted { left, right in
            left.path < right.path
        }
        for component in components where !component.environmentSnapshot.values.isEmpty {
            environments[component.path] = try self.environment(
                from: component.environmentSnapshot,
                base: base
            )
        }
        return environments
    }

    func environment(
        from index: BrowserHydrationIndex,
        base: EnvironmentValues = EnvironmentValues()
    ) throws -> EnvironmentValues {
        var environment = base
        let components = index.components.sorted { left, right in
            left.path < right.path
        }
        for component in components where !component.environmentSnapshot.values.isEmpty {
            environment = try self.environment(
                from: component.environmentSnapshot,
                base: environment
            )
        }
        return environment
    }
}
