import Foundation
import SwiftHTML
import SwiftWebStyle

public struct ClientWasmBootstrapLocation: Sendable, Codable, Equatable {
    public let href: String
    public let search: String

    public init(href: String, search: String) {
        self.href = href
        self.search = search
    }
}

public struct ClientWasmBootstrapRequest: Sendable, Codable, Equatable {
    public let hydrationIndex: BrowserHydrationIndex
    public let location: ClientWasmBootstrapLocation
    public let mode: ClientWasmBootstrapMode?
    public let stateSnapshot: ClientWasmStateSnapshot?

    public init(
        hydrationIndex: BrowserHydrationIndex,
        location: ClientWasmBootstrapLocation,
        mode: ClientWasmBootstrapMode? = nil,
        stateSnapshot: ClientWasmStateSnapshot? = nil
    ) {
        self.hydrationIndex = hydrationIndex
        self.location = location
        self.mode = mode
        self.stateSnapshot = stateSnapshot
    }
}

public enum ClientWasmBootstrapMode: String, Sendable, Codable, Equatable {
    case standard
    case hotReload
}

public typealias ClientWasmStateSnapshot = StateStoreSnapshot

public struct ClientWasmEventRequest: Sendable, Codable, Equatable {
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

public struct ClientWasmRuntimeResponse: Sendable, Codable, Equatable {
    public let commandBatch: BrowserDOMCommandBatch?
    public let hydrationIndex: BrowserHydrationIndex?
    public let error: String?
    public let appliesDOMCommandsInRuntime: Bool

    public init(
        commandBatch: BrowserDOMCommandBatch? = nil,
        hydrationIndex: BrowserHydrationIndex? = nil,
        error: String? = nil,
        appliesDOMCommandsInRuntime: Bool = false
    ) {
        self.commandBatch = commandBatch
        self.hydrationIndex = hydrationIndex
        self.error = error
        self.appliesDOMCommandsInRuntime = appliesDOMCommandsInRuntime
    }
}

public enum ClientWasmRuntimeBridgeError: Error, Sendable, CustomStringConvertible {
    case notBootstrapped
    case componentMountNotFound(String)

    public var description: String {
        switch self {
        case .notBootstrapped:
            "SwiftHTML WASM runtime was not bootstrapped"
        case .componentMountNotFound(let typeName):
            "SwiftHTML WASM component mount was not found for \(typeName)"
        }
    }
}

public struct ClientWasmComponentMount: Sendable, Equatable {
    public let typeName: String
    public let componentID: ComponentID?

    public init<Root: HTML>(_ type: Root.Type) {
        self.typeName = String(reflecting: type)
        self.componentID = nil
    }

    public init(typeName: String, componentID: ComponentID? = nil) {
        self.typeName = typeName
        self.componentID = componentID
    }
}

public final class ClientWasmRuntimeBridge<Root: HTML> {
    public typealias RootFactory = @Sendable (ClientWasmBootstrapRequest) throws -> Root
    public typealias EnvironmentFactory = @Sendable (ClientWasmBootstrapRequest) throws -> EnvironmentValues
    public typealias ComponentEnvironmentFactory = @Sendable (
        ClientWasmBootstrapRequest,
        EnvironmentValues
    ) throws -> [String: EnvironmentValues]

    private let rootFactory: RootFactory
    private let environmentFactory: EnvironmentFactory
    private let componentEnvironmentFactory: ComponentEnvironmentFactory
    private let componentMount: ClientWasmComponentMount?
    private let domHost: (any BrowserDOMHost)?
    private let stateStore: StateStore
    private var session: HydrationRuntimeSession<Root>?
    private var mountedHydrationIndex: BrowserHydrationIndex?
    private var mountedNodeMap: [HTMLNodeID: HTMLNodeID] = [:]

    public init(
        environmentRegistry: ClientEnvironmentRegistry = .empty,
        componentMount: ClientWasmComponentMount? = nil,
        domHost: (any BrowserDOMHost)? = nil,
        stateStore: StateStore = StateStore(),
        rootFactory: @escaping RootFactory
    ) {
        self.rootFactory = rootFactory
        self.componentMount = componentMount
        self.domHost = domHost
        self.stateStore = stateStore
        self.environmentFactory = { _ in
            EnvironmentValues()
        }
        self.componentEnvironmentFactory = { request, base in
            try environmentRegistry.componentEnvironments(from: request.hydrationIndex, base: base)
        }
    }

    public init(
        componentMount: ClientWasmComponentMount? = nil,
        domHost: (any BrowserDOMHost)? = nil,
        stateStore: StateStore = StateStore(),
        rootFactory: @escaping RootFactory,
        environmentFactory: @escaping EnvironmentFactory,
        componentEnvironmentFactory: @escaping ComponentEnvironmentFactory = { _, _ in [:] }
    ) {
        self.rootFactory = rootFactory
        self.componentMount = componentMount
        self.domHost = domHost
        self.stateStore = stateStore
        self.environmentFactory = environmentFactory
        self.componentEnvironmentFactory = componentEnvironmentFactory
    }

    public func bootstrap(_ request: ClientWasmBootstrapRequest) throws -> ClientWasmRuntimeResponse {
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
        session = try StyleRegistry.withCurrent(styleRegistry) {
            try makeSession(
                root: root,
                environment: environment,
                options: options,
                restoring: request.stateSnapshot
            )
        }
        #if os(WASI)
        JavaScriptKitBrowserRuntime.flushAtomicRules(styleRegistry.rules())
        #endif
        if let componentMount {
            let localIndex = session?.artifact.browserHydrationIndex() ?? .empty
            mountedHydrationIndex = request.hydrationIndex
            let initialNodeMap = try Self.nodeMap(
                localIndex: localIndex,
                mountedIndex: request.hydrationIndex,
                mount: componentMount
            )
            mountedNodeMap = initialNodeMap
            if request.mode == .hotReload {
                let nextNodeMap = Self.structuralNodeMap(
                    localIndex: localIndex,
                    mountedIndex: request.hydrationIndex,
                    mount: componentMount
                )
                let previousNodeMap = Self.boundaryNodeMap(
                    mountedIndex: request.hydrationIndex,
                    mount: componentMount
                )
                let commandBatch = Self.hotReloadCommandBatch(
                    localArtifact: session?.artifact,
                    localIndex: localIndex,
                    mountedIndex: request.hydrationIndex,
                    nodeMap: nextNodeMap,
                    mount: componentMount
                )
                let nextHydrationIndex = Self.rebased(
                    localIndex,
                    mountedIndex: request.hydrationIndex,
                    previousNodeMap: previousNodeMap,
                    nodeMap: nextNodeMap
                )
                mountedHydrationIndex = nextHydrationIndex
                mountedNodeMap = nextNodeMap
                if let domHost {
                    try domHost.apply(commandBatch, currentIndex: request.hydrationIndex)
                }
                return ClientWasmRuntimeResponse(
                    commandBatch: commandBatch,
                    hydrationIndex: nextHydrationIndex,
                    appliesDOMCommandsInRuntime: domHost != nil
                )
            }
            return ClientWasmRuntimeResponse(
                commandBatch: BrowserDOMCommandBatch(commands: []),
                hydrationIndex: request.hydrationIndex
            )
        }

        return ClientWasmRuntimeResponse(
            commandBatch: BrowserDOMCommandBatch(commands: []),
            hydrationIndex: session?.artifact.browserHydrationIndex()
        )
    }

    public func snapshotState() throws -> ClientWasmStateSnapshot {
        guard let session else {
            return .empty
        }
        return try stateStore.snapshot(schemaHash: session.artifact.hydration.stateSchemaHash)
    }

    public func restoreState(_ snapshot: ClientWasmStateSnapshot) {
        guard let session,
              let rebasedSnapshot = Self.rebasedSnapshot(snapshot, into: session.artifact)
        else {
            return
        }
        stateStore.restore(rebasedSnapshot)
    }

    public func dispatch(_ request: ClientWasmEventRequest) throws -> ClientWasmRuntimeResponse {
        guard var session else {
            throw ClientWasmRuntimeBridgeError.notBootstrapped
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
                    handlerID: translatedHandlerID(request.handlerID, in: session),
                    event: request.event
                )
            }
        }
        #if os(WASI)
        JavaScriptKitBrowserRuntime.flushAtomicRules(styleRegistry.rules())
        #endif
        self.session = session
        let commandBatch: BrowserDOMCommandBatch
        let hydrationIndex: BrowserHydrationIndex?
        let currentIndexForDOM: BrowserHydrationIndex
        if let componentMount {
            let mountedIndex = mountedHydrationIndex ?? update.hydrationIndex
            currentIndexForDOM = mountedIndex
            let previousNodeMap = mountedNodeMap
            let nextNodeMap = Self.structuralNodeMap(
                localIndex: update.hydrationIndex,
                mountedIndex: mountedIndex,
                mount: componentMount
            )
            let nextHydrationIndex = Self.rebased(
                update.hydrationIndex,
                mountedIndex: mountedIndex,
                previousNodeMap: previousNodeMap,
                nodeMap: nextNodeMap
            )
            let mountedComponentsByNodeID = Dictionary(uniqueKeysWithValues: mountedIndex.components.map {
                ($0.nodeID, $0)
            })
            let mountedServerSlotsByNodeID = Dictionary(uniqueKeysWithValues: mountedIndex.serverSlots.map {
                ($0.nodeID, $0)
            })
            let nextComponentIDMap = Self.componentIDMap(
                localIndex: update.hydrationIndex,
                mountedComponentsByNodeID: mountedComponentsByNodeID,
                nodeMap: nextNodeMap
            )
            let nextServerSlotIDMap = Self.serverSlotIDMap(
                localIndex: update.hydrationIndex,
                mountedServerSlotsByNodeID: mountedServerSlotsByNodeID,
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
            mountedNodeMap = nextNodeMap
            mountedHydrationIndex = nextHydrationIndex
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
        return ClientWasmRuntimeResponse(
            commandBatch: commandBatch,
            hydrationIndex: hydrationIndex,
            appliesDOMCommandsInRuntime: domHost != nil
        )
    }

    private func makeSession(
        root: Root,
        environment: EnvironmentValues,
        options: HTMLRenderOptions,
        restoring snapshot: ClientWasmStateSnapshot?
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
        in session: HydrationRuntimeSession<Root>
    ) -> HandlerID {
        guard componentMount != nil,
              let mountedHydrationIndex,
              let mountedBinding = mountedHydrationIndex.handlers.first(where: { binding in
                  binding.handlerID == mountedHandlerID
              })
        else {
            return mountedHandlerID
        }

        let mountedToLocalNodeMap = Dictionary(uniqueKeysWithValues: mountedNodeMap.map { localID, mountedID in
            (mountedID, localID)
        })
        guard let localNodeID = mountedToLocalNodeMap[mountedBinding.nodeID] else {
            return mountedHandlerID
        }

        let localIndex = session.artifact.browserHydrationIndex()
        return localIndex.handlers.first { binding in
            binding.nodeID == localNodeID
                && binding.eventName == mountedBinding.eventName
        }?.handlerID ?? mountedHandlerID
    }

    private static func canRestore(
        _ snapshot: ClientWasmStateSnapshot,
        into artifact: RenderArtifact
    ) -> Bool {
        snapshot.schemaHash == artifact.hydration.stateSchemaHash
    }

    private static func rebasedSnapshot(
        _ snapshot: ClientWasmStateSnapshot,
        into artifact: RenderArtifact
    ) -> ClientWasmStateSnapshot? {
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
        guard let range = stateSlotID.range(of: ":state:") else {
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
        mount: ClientWasmComponentMount
    ) throws -> [HTMLNodeID: HTMLNodeID] {
        guard let localComponent = Self.component(in: localIndex, matching: mount) else {
            throw ClientWasmRuntimeBridgeError.componentMountNotFound(mount.typeName)
        }
        guard let mountedComponent = Self.component(in: mountedIndex, matching: mount) else {
            throw ClientWasmRuntimeBridgeError.componentMountNotFound(mount.typeName)
        }

        var map: [HTMLNodeID: HTMLNodeID] = [:]
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
        nodeMap: [HTMLNodeID: HTMLNodeID],
        mount: ClientWasmComponentMount
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
        let mountedToLocal = Dictionary(uniqueKeysWithValues: nodeMap.map { ($0.value, $0.key) })
        let mountedComponentsByNodeID = Dictionary(uniqueKeysWithValues: mountedIndex.components.map {
            ($0.nodeID, $0)
        })
        let mountedServerSlotsByNodeID = Dictionary(uniqueKeysWithValues: mountedIndex.serverSlots.map {
            ($0.nodeID, $0)
        })
        let componentIDMap = componentIDMap(
            localIndex: localIndex,
            mountedComponentsByNodeID: mountedComponentsByNodeID,
            nodeMap: nodeMap
        )
        let serverSlotIDMap = serverSlotIDMap(
            localIndex: localIndex,
            mountedServerSlotsByNodeID: mountedServerSlotsByNodeID,
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
        matching mount: ClientWasmComponentMount
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
        localToMounted: [HTMLNodeID: HTMLNodeID],
        mountedToLocal: [HTMLNodeID: HTMLNodeID],
        componentIDMap: [ComponentID: ComponentID],
        serverSlotIDMap: [ServerSlotID: ServerSlotID],
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
        localToMounted: [HTMLNodeID: HTMLNodeID],
        mountedToLocal: [HTMLNodeID: HTMLNodeID],
        componentIDMap: [ComponentID: ComponentID],
        serverSlotIDMap: [ServerSlotID: ServerSlotID],
        commands: inout [BrowserDOMCommand]
    ) {
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

            guard let mountedIndex = mountedNode.childIDs.firstIndex(of: mountedChildID),
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
        into map: inout [HTMLNodeID: HTMLNodeID]
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
        previousNodeMap: [HTMLNodeID: HTMLNodeID],
        nextNodeMap: [HTMLNodeID: HTMLNodeID],
        componentIDMap: [ComponentID: ComponentID],
        serverSlotIDMap: [ServerSlotID: ServerSlotID]
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
        previousNodeMap: [HTMLNodeID: HTMLNodeID],
        nextNodeMap: [HTMLNodeID: HTMLNodeID],
        componentIDMap: [ComponentID: ComponentID],
        serverSlotIDMap: [ServerSlotID: ServerSlotID]
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
        mount: ClientWasmComponentMount
    ) -> [HTMLNodeID: HTMLNodeID] {
        guard let localComponent = localIndex.components.first(where: { $0.typeName == mount.typeName }),
              let mountedComponent = mountedIndex.components.first(where: { $0.typeName == mount.typeName }) else {
            return [:]
        }

        var map: [HTMLNodeID: HTMLNodeID] = [:]
        var allocatedMountedIDs = Set(mountedIndex.nodes.map(\.id))
        var nextNodeID = (mountedIndex.nodes.map(\.id.rawValue).max() ?? -1) + 1

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
        mount: ClientWasmComponentMount
    ) -> [HTMLNodeID: HTMLNodeID] {
        guard let mountedComponent = mountedIndex.components.first(where: { $0.typeName == mount.typeName }) else {
            return [:]
        }

        var map: [HTMLNodeID: HTMLNodeID] = [:]
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
    ) -> [HTMLNodeID: HTMLNodeID] {
        var matches: [HTMLNodeID: HTMLNodeID] = [:]
        var usedMountedIDs = Set<HTMLNodeID>()
        var mountedKeyed: [Key: HTMLNodeID] = [:]

        for mountedID in mountedChildren {
            guard let mountedNode = mountedIndex.node(mountedID), let key = mountedNode.key else {
                continue
            }
            mountedKeyed[key] = mountedID
        }

        for localID in localChildren {
            guard let localNode = localIndex.node(localID), let key = localNode.key else {
                continue
            }
            if let mountedID = mountedKeyed[key],
               let mountedNode = mountedIndex.node(mountedID),
               nodesAreCompatible(localNode, mountedNode) {
                matches[localID] = mountedID
                usedMountedIDs.insert(mountedID)
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

    private static func nodesAreCompatible(
        _ localNode: BrowserHydrationNodeRecord,
        _ mountedNode: BrowserHydrationNodeRecord
    ) -> Bool {
        localNode.role == mountedNode.role
            && localNode.name == mountedNode.name
            && localNode.componentID.map { _ in true } == mountedNode.componentID.map { _ in true }
            && localNode.serverSlotID.map { _ in true } == mountedNode.serverSlotID.map { _ in true }
    }

    private static func rebased(
        _ localIndex: BrowserHydrationIndex,
        mountedIndex: BrowserHydrationIndex,
        previousNodeMap: [HTMLNodeID: HTMLNodeID],
        nodeMap: [HTMLNodeID: HTMLNodeID]
    ) -> BrowserHydrationIndex {
        let previousMountedNodes = Set(previousNodeMap.values)
        let mountedNodesByID = Dictionary(uniqueKeysWithValues: mountedIndex.nodes.map { ($0.id, $0) })
        let mountedComponentsByNodeID = Dictionary(uniqueKeysWithValues: mountedIndex.components.map {
            ($0.nodeID, $0)
        })
        let componentIDMap = componentIDMap(
            localIndex: localIndex,
            mountedComponentsByNodeID: mountedComponentsByNodeID,
            nodeMap: nodeMap
        )
        let outsideNodes = mountedIndex.nodes.filter { node in
            !previousMountedNodes.contains(node.id)
        }
        let rebasedNodes = localIndex.nodes.compactMap { node in
            rebased(
                node,
                nodeMap: nodeMap,
                componentIDMap: componentIDMap,
                mountedNodesByID: mountedNodesByID,
                mountedIndex: mountedIndex
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
                mountedComponentsByNodeID: mountedComponentsByNodeID
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
                mountedIndex: mountedIndex
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

    private static func componentIDMap(
        localIndex: BrowserHydrationIndex,
        mountedComponentsByNodeID: [HTMLNodeID: BrowserHydrationComponentRecord],
        nodeMap: [HTMLNodeID: HTMLNodeID]
    ) -> [ComponentID: ComponentID] {
        var map: [ComponentID: ComponentID] = [:]
        for component in localIndex.components {
            if let mountedNodeID = nodeMap[component.nodeID],
               let mountedComponent = mountedComponentsByNodeID[mountedNodeID] {
                map[component.id] = mountedComponent.id
            } else {
                map[component.id] = component.id
            }
        }
        return map
    }

    private static func serverSlotIDMap(
        localIndex: BrowserHydrationIndex,
        mountedServerSlotsByNodeID: [HTMLNodeID: ServerSlotRecord],
        nodeMap: [HTMLNodeID: HTMLNodeID]
    ) -> [ServerSlotID: ServerSlotID] {
        var map: [ServerSlotID: ServerSlotID] = [:]
        for slot in localIndex.serverSlots {
            if let mountedNodeID = nodeMap[slot.nodeID],
               let mountedSlot = mountedServerSlotsByNodeID[mountedNodeID] {
                map[slot.id] = mountedSlot.id
            } else {
                map[slot.id] = slot.id
            }
        }
        return map
    }

    private static func renderRebasedSubtree(
        _ artifact: RenderArtifact,
        node: HTMLNodeID,
        nodeMap: [HTMLNodeID: HTMLNodeID],
        componentIDMap: [ComponentID: ComponentID],
        serverSlotIDMap: [ServerSlotID: ServerSlotID]
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
        nodeMap: [HTMLNodeID: HTMLNodeID],
        componentIDMap: [ComponentID: ComponentID],
        serverSlotIDMap: [ServerSlotID: ServerSlotID]
    ) -> String {
        var result = rebaseNodeMarkers(in: html, nodeMap: nodeMap)
        for (source, target) in componentIDMap where source != target {
            result = result.replacingOccurrences(
                of: HTMLRuntimeMarkers.componentCommentValue(source, edge: .begin),
                with: HTMLRuntimeMarkers.componentCommentValue(target, edge: .begin)
            )
            result = result.replacingOccurrences(
                of: HTMLRuntimeMarkers.componentCommentValue(source, edge: .end),
                with: HTMLRuntimeMarkers.componentCommentValue(target, edge: .end)
            )
        }
        for (source, target) in serverSlotIDMap where source != target {
            result = result.replacingOccurrences(
                of: HTMLRuntimeMarkers.serverSlotCommentValue(source, edge: .begin),
                with: HTMLRuntimeMarkers.serverSlotCommentValue(target, edge: .begin)
            )
            result = result.replacingOccurrences(
                of: HTMLRuntimeMarkers.serverSlotCommentValue(source, edge: .end),
                with: HTMLRuntimeMarkers.serverSlotCommentValue(target, edge: .end)
            )
        }
        return result
    }

    private static func rebaseNodeMarkers(
        in html: String,
        nodeMap: [HTMLNodeID: HTMLNodeID]
    ) -> String {
        let marker = "\(HTMLRuntimeMarkers.nodeAttribute)=\""
        var output = ""
        var cursor = html.startIndex

        while let range = html[cursor...].range(of: marker) {
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
        nodeMap: [HTMLNodeID: HTMLNodeID],
        componentIDMap: [ComponentID: ComponentID],
        mountedNodesByID: [HTMLNodeID: BrowserHydrationNodeRecord],
        mountedIndex: BrowserHydrationIndex
    ) -> BrowserHydrationNodeRecord? {
        guard let mappedID = nodeMap[node.id] else {
            return nil
        }
        let mountedNode = mountedNodesByID[mappedID]
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
                    mountedIndex: mountedIndex
                )
            },
            key: node.key,
            fingerprint: node.fingerprint
        )
    }

    private static func rebased(
        _ component: BrowserHydrationComponentRecord,
        nodeMap: [HTMLNodeID: HTMLNodeID],
        componentIDMap: [ComponentID: ComponentID],
        mountedComponentsByNodeID: [HTMLNodeID: BrowserHydrationComponentRecord]
    ) -> BrowserHydrationComponentRecord? {
        guard let mappedNodeID = nodeMap[component.nodeID] else {
            return nil
        }
        if let mountedComponent = mountedComponentsByNodeID[mappedNodeID] {
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
        nodeMap: [HTMLNodeID: HTMLNodeID],
        componentIDMap: [ComponentID: ComponentID]
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
        nodeMap: [HTMLNodeID: HTMLNodeID],
        componentIDMap: [ComponentID: ComponentID],
        mountedIndex: BrowserHydrationIndex
    ) -> BrowserHydrationEventBinding? {
        guard let mappedNodeID = nodeMap[binding.nodeID] else {
            return nil
        }
        let mountedHandlerID = mountedIndex.handlers.first { mountedBinding in
            mountedBinding.nodeID == mappedNodeID
                && mountedBinding.eventName == binding.eventName
        }?.handlerID ?? binding.handlerID
        return BrowserHydrationEventBinding(
            nodeID: mappedNodeID,
            handlerID: mountedHandlerID,
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
