import SwiftHTML
import SwiftWebUIRuntime
import Testing

private struct WasmBridgeCounter: ClientComponent, Sendable {
    @State private var value = 0

    var body: some HTML {
        button(.type(ButtonType.button), .onClick {
            value += 1
        }) {
            "\(value)"
        }
    }
}

private struct WasmBridgeAppendList: ClientComponent, Sendable {
    @State private var values = [1, 2]

    var body: some HTML {
        button(.type(ButtonType.button), .onClick {
            values.append((values.last ?? 0) + 1)
        }) {
            "Append"
        }
        ul {
            ForEach(values, id: { value in value }) { value in
                li {
                    "Item \(value)"
                }
            }
        }
    }
}

private struct WasmBridgeEnvironmentKey: ClientEnvironmentKey {
    static let defaultValue = "default"
}

private extension EnvironmentValues {
    var wasmBridgeValue: String {
        get { self[WasmBridgeEnvironmentKey.self] }
        set { self[WasmBridgeEnvironmentKey.self] = newValue }
    }
}

private struct WasmBridgeEnvironmentReader: ClientComponent {
    @Environment(\.wasmBridgeValue) private var value: String

    var body: some HTML {
        span {
            value
        }
    }
}

private struct WasmBridgeScopedEnvironmentRoot: Component, Sendable {
    let left: String
    let right: String

    var body: some HTML {
        div {
            WasmBridgeEnvironmentReader()
                .environment(\.wasmBridgeValue, left)
            WasmBridgeEnvironmentReader()
                .environment(\.wasmBridgeValue, right)
        }
    }
}

private enum WasmBridgeHotReloadFixture {
    nonisolated(unsafe) static var text = "Before"
}

private struct WasmBridgeHotReloadComponent: ClientComponent, Sendable {
    var body: some HTML {
        span {
            WasmBridgeHotReloadFixture.text
        }
    }
}

private enum WasmBridgeHotReloadStateFixture {
    nonisolated(unsafe) static var text = "Before"
}

private struct WasmBridgeHotReloadStatefulComponent: ClientComponent, Sendable {
    @State private var value = 0

    var body: some HTML {
        button(.type(ButtonType.button), .onClick {
            value += 1
        }) {
            "\(WasmBridgeHotReloadStateFixture.text) \(value)"
        }
    }
}

private enum WasmBridgeHotReloadStructureFixture {
    nonisolated(unsafe) static var showsDetail = false
}

private struct WasmBridgeHotReloadStructuralComponent: ClientComponent, Sendable {
    var body: some HTML {
        div {
            span {
                "Stable"
            }
            if WasmBridgeHotReloadStructureFixture.showsDetail {
                p {
                    "Inserted"
                }
            }
        }
    }
}

private struct WasmBridgeMountedRoot: Component, Sendable {
    var body: some HTML {
        div {
            span {
                "server prefix"
            }
            WasmBridgeCounter()
        }
    }
}

private struct WasmBridgeMountedRootWithEarlierHandler: Component, Sendable {
    var body: some HTML {
        div {
            button(.type(ButtonType.button), .onClick {}) {
                "server action"
            }
            WasmBridgeCounter()
        }
    }
}

private struct WasmBridgeMountedListRoot: Component, Sendable {
    var body: some HTML {
        div {
            span {
                "server prefix"
            }
            WasmBridgeAppendList()
        }
    }
}

@Suite(.serialized)
struct SwiftWebUIRuntimeClientWasmRuntimeBridgeTests {
    @Test
    func bridgeBootstrapsAndDispatchesClientStateWithoutServerSession() throws {
        let bridge = ClientWasmRuntimeBridge<WasmBridgeCounter> { _ in
            WasmBridgeCounter()
        }

        let bootstrap = try bridge.bootstrap(
            ClientWasmBootstrapRequest(
                hydrationIndex: .empty,
                location: ClientWasmBootstrapLocation(
                    href: "http://127.0.0.1:8080/counter?server=8",
                    search: "?server=8"
                )
            )
        )
        let handler = try #require(bootstrap.hydrationIndex?.handlers.first)
        let update = try bridge.dispatch(
            ClientWasmEventRequest(
                handlerID: handler.handlerID,
                event: DOMEvent()
            )
        )

        #expect(update.commandBatch?.commands == [
            .updateText(node: HTMLNodeID(0), value: "1"),
        ])
        #expect(update.hydrationIndex?.handlers.map(\.handlerID) == [handler.handlerID])
    }

    @Test
    func bridgeCanMountAClientComponentInsideAServerRenderedPage() throws {
        let serverArtifact = WasmBridgeMountedRoot().renderArtifact()
        let serverIndex = serverArtifact.browserHydrationIndex()
        let serverValueNode = try #require(serverIndex.nodes.first { node in
            node.role == .text && node.text == "0"
        })
        let bridge = ClientWasmRuntimeBridge<WasmBridgeCounter>(
            componentMount: ClientWasmComponentMount(WasmBridgeCounter.self)
        ) { _ in
            WasmBridgeCounter()
        }

        let bootstrap = try bridge.bootstrap(
            ClientWasmBootstrapRequest(
                hydrationIndex: serverIndex,
                location: ClientWasmBootstrapLocation(
                    href: "http://127.0.0.1:8080/counter",
                    search: ""
                )
            )
        )
        let handler = try #require(serverIndex.handlers.first)
        let update = try bridge.dispatch(
            ClientWasmEventRequest(
                handlerID: handler.handlerID,
                event: DOMEvent()
            )
        )

        #expect(bootstrap.hydrationIndex == serverIndex)
        #expect(update.hydrationIndex?.handlers.map(\.handlerID) == serverIndex.handlers.map(\.handlerID))
        #expect(update.hydrationIndex?.node(serverValueNode.id)?.text == "1")
        #expect(update.commandBatch?.commands == [
            .updateText(node: serverValueNode.id, value: "1"),
        ])
    }

    @Test
    func bridgeTranslatesMountedHandlerIDsWhenServerPageHasEarlierHandlers() throws {
        let serverArtifact = WasmBridgeMountedRootWithEarlierHandler().renderArtifact()
        let serverIndex = serverArtifact.browserHydrationIndex()
        let counterComponent = try #require(serverIndex.components.first { component in
            component.typeName == String(reflecting: WasmBridgeCounter.self)
        })
        let counterHandler = try #require(serverIndex.handlers.first { binding in
            binding.componentID == counterComponent.id
        })
        let serverValueNode = try #require(serverIndex.nodes.first { node in
            node.role == .text && node.text == "0"
        })
        let serverHandlerIDs = Set(serverIndex.handlers.map(\.handlerID))
        let bridge = ClientWasmRuntimeBridge<WasmBridgeCounter>(
            componentMount: ClientWasmComponentMount(WasmBridgeCounter.self)
        ) { _ in
            WasmBridgeCounter()
        }

        _ = try bridge.bootstrap(
            ClientWasmBootstrapRequest(
                hydrationIndex: serverIndex,
                location: ClientWasmBootstrapLocation(
                    href: "http://127.0.0.1:8080/counter",
                    search: ""
                )
            )
        )
        let firstUpdate = try bridge.dispatch(
            ClientWasmEventRequest(
                handlerID: counterHandler.handlerID,
                event: DOMEvent()
            )
        )
        let secondUpdate = try bridge.dispatch(
            ClientWasmEventRequest(
                handlerID: counterHandler.handlerID,
                event: DOMEvent()
            )
        )

        #expect(firstUpdate.commandBatch?.commands == [
            .updateText(node: serverValueNode.id, value: "1"),
        ])
        #expect(firstUpdate.hydrationIndex?.handlers.contains { binding in
            binding.handlerID == counterHandler.handlerID
        } == true)
        #expect(Set(firstUpdate.hydrationIndex?.handlers.map(\.handlerID) ?? []) == serverHandlerIDs)
        #expect(secondUpdate.commandBatch?.commands == [
            .updateText(node: serverValueNode.id, value: "2"),
        ])
        #expect(secondUpdate.hydrationIndex?.handlers.contains { binding in
            binding.handlerID == counterHandler.handlerID
        } == true)
        #expect(Set(secondUpdate.hydrationIndex?.handlers.map(\.handlerID) ?? []) == serverHandlerIDs)
    }

    @Test
    func bridgeHotReloadModeProducesTextPatchForCompatibleComponent() throws {
        WasmBridgeHotReloadFixture.text = "Before"
        let serverArtifact = WasmBridgeHotReloadComponent().renderArtifact()
        let serverIndex = serverArtifact.browserHydrationIndex()
        let textNode = try #require(serverIndex.nodes.first { node in
            node.role == .text && node.text == "Before"
        })
        WasmBridgeHotReloadFixture.text = "After"
        let bridge = ClientWasmRuntimeBridge<WasmBridgeHotReloadComponent>(
            componentMount: ClientWasmComponentMount(WasmBridgeHotReloadComponent.self)
        ) { _ in
            WasmBridgeHotReloadComponent()
        }

        let response = try bridge.bootstrap(
            ClientWasmBootstrapRequest(
                hydrationIndex: serverIndex,
                location: ClientWasmBootstrapLocation(
                    href: "http://127.0.0.1:8080/storyboard",
                    search: ""
                ),
                mode: .hotReload
            )
        )

        #expect(response.commandBatch?.commands.contains {
            $0 == .updateText(node: textNode.id, value: "After")
        } == true)
    }

    @Test
    func bridgeHotReloadModeProducesStructuralPatchForInsertedNode() throws {
        WasmBridgeHotReloadStructureFixture.showsDetail = false
        let serverArtifact = WasmBridgeHotReloadStructuralComponent().renderArtifact()
        let serverIndex = serverArtifact.browserHydrationIndex()
        WasmBridgeHotReloadStructureFixture.showsDetail = true
        let bridge = ClientWasmRuntimeBridge<WasmBridgeHotReloadStructuralComponent>(
            componentMount: ClientWasmComponentMount(WasmBridgeHotReloadStructuralComponent.self)
        ) { _ in
            WasmBridgeHotReloadStructuralComponent()
        }

        let response = try bridge.bootstrap(
            ClientWasmBootstrapRequest(
                hydrationIndex: serverIndex,
                location: ClientWasmBootstrapLocation(
                    href: "http://127.0.0.1:8080/storyboard",
                    search: ""
                ),
                mode: .hotReload
            )
        )

        #expect(response.commandBatch?.commands.contains { command in
            if case .insertHTML(_, _, let html) = command {
                return html.contains("Inserted")
            }
            return false
        } == true)
        #expect(response.hydrationIndex?.nodes.contains { node in
            node.role == .text && node.text == "Inserted"
        } == true)
        try assertCommandTargetsResolve(response)
    }

    @Test
    func bridgeHotReloadRestoresStateWhenSchemaMatches() throws {
        WasmBridgeHotReloadStateFixture.text = "Before"
        let serverArtifact = WasmBridgeHotReloadStatefulComponent().renderArtifact()
        let serverIndex = serverArtifact.browserHydrationIndex()
        let oldBridge = ClientWasmRuntimeBridge<WasmBridgeHotReloadStatefulComponent>(
            componentMount: ClientWasmComponentMount(WasmBridgeHotReloadStatefulComponent.self)
        ) { _ in
            WasmBridgeHotReloadStatefulComponent()
        }

        _ = try oldBridge.bootstrap(
            ClientWasmBootstrapRequest(
                hydrationIndex: serverIndex,
                location: ClientWasmBootstrapLocation(
                    href: "http://127.0.0.1:8080/storyboard",
                    search: ""
                )
            )
        )
        let handler = try #require(serverIndex.handlers.first)
        let incremented = try oldBridge.dispatch(
            ClientWasmEventRequest(
                handlerID: handler.handlerID,
                event: DOMEvent()
            )
        )
        let incrementedIndex = try #require(incremented.hydrationIndex)
        let incrementedTextNode = try #require(incremented.commandBatch?.commands.compactMap(textUpdateNode).first)
        let snapshot = try oldBridge.snapshotState()

        WasmBridgeHotReloadStateFixture.text = "After"
        let newBridge = ClientWasmRuntimeBridge<WasmBridgeHotReloadStatefulComponent>(
            componentMount: ClientWasmComponentMount(WasmBridgeHotReloadStatefulComponent.self)
        ) { _ in
            WasmBridgeHotReloadStatefulComponent()
        }

        let response = try newBridge.bootstrap(
            ClientWasmBootstrapRequest(
                hydrationIndex: incrementedIndex,
                location: ClientWasmBootstrapLocation(
                    href: "http://127.0.0.1:8080/storyboard",
                    search: ""
                ),
                mode: .hotReload,
                stateSnapshot: snapshot
            )
        )

        #expect(snapshot.values.count == 1)
        #expect(response.hydrationIndex?.nodes.contains { node in
            node.role == .text && node.text == "After 1"
        } == true)
        #expect(response.commandBatch?.commands.contains { command in
            command == .updateText(node: incrementedTextNode, value: "After 1")
        } == true)
    }

    @Test
    func bridgeHotReloadRebasesStateWhenComponentIDChangesButSourceMatches() throws {
        WasmBridgeHotReloadStateFixture.text = "Before"
        let serverArtifact = WasmBridgeHotReloadStatefulComponent().renderArtifact()
        let serverIndex = serverArtifact.browserHydrationIndex()
        let oldBridge = ClientWasmRuntimeBridge<WasmBridgeHotReloadStatefulComponent>(
            componentMount: ClientWasmComponentMount(WasmBridgeHotReloadStatefulComponent.self)
        ) { _ in
            WasmBridgeHotReloadStatefulComponent()
        }

        _ = try oldBridge.bootstrap(
            ClientWasmBootstrapRequest(
                hydrationIndex: serverIndex,
                location: ClientWasmBootstrapLocation(
                    href: "http://127.0.0.1:8080/storyboard",
                    search: ""
                )
            )
        )
        let handler = try #require(serverIndex.handlers.first)
        let incremented = try oldBridge.dispatch(
            ClientWasmEventRequest(
                handlerID: handler.handlerID,
                event: DOMEvent()
            )
        )
        let incrementedIndex = try #require(incremented.hydrationIndex)
        let incrementedTextNode = try #require(incremented.commandBatch?.commands.compactMap(textUpdateNode).first)
        let snapshot = try oldBridge.snapshotState()
        let snapshotWithChangedComponentID = ClientWasmStateSnapshot(
            schemaHash: "legacy-component-id",
            values: Dictionary(uniqueKeysWithValues: snapshot.values.map { key, value in
                let sourceSuffix = key.range(of: ":state:").map { range in
                    String(key[range.lowerBound...])
                } ?? key
                return ("legacy-component\(sourceSuffix)", value)
            })
        )

        WasmBridgeHotReloadStateFixture.text = "After"
        let newBridge = ClientWasmRuntimeBridge<WasmBridgeHotReloadStatefulComponent>(
            componentMount: ClientWasmComponentMount(WasmBridgeHotReloadStatefulComponent.self)
        ) { _ in
            WasmBridgeHotReloadStatefulComponent()
        }

        let response = try newBridge.bootstrap(
            ClientWasmBootstrapRequest(
                hydrationIndex: incrementedIndex,
                location: ClientWasmBootstrapLocation(
                    href: "http://127.0.0.1:8080/storyboard",
                    search: ""
                ),
                mode: .hotReload,
                stateSnapshot: snapshotWithChangedComponentID
            )
        )

        #expect(response.hydrationIndex?.nodes.contains { node in
            node.role == .text && node.text == "After 1"
        } == true)
        #expect(response.commandBatch?.commands.contains { command in
            command == .updateText(node: incrementedTextNode, value: "After 1")
        } == true)
    }

    @Test
    func bridgeHotReloadDropsStateWhenSchemaMismatches() throws {
        WasmBridgeHotReloadStateFixture.text = "Before"
        let serverArtifact = WasmBridgeHotReloadStatefulComponent().renderArtifact()
        let serverIndex = serverArtifact.browserHydrationIndex()
        let oldBridge = ClientWasmRuntimeBridge<WasmBridgeHotReloadStatefulComponent>(
            componentMount: ClientWasmComponentMount(WasmBridgeHotReloadStatefulComponent.self)
        ) { _ in
            WasmBridgeHotReloadStatefulComponent()
        }

        _ = try oldBridge.bootstrap(
            ClientWasmBootstrapRequest(
                hydrationIndex: serverIndex,
                location: ClientWasmBootstrapLocation(
                    href: "http://127.0.0.1:8080/storyboard",
                    search: ""
                )
            )
        )
        let handler = try #require(serverIndex.handlers.first)
        let incremented = try oldBridge.dispatch(
            ClientWasmEventRequest(
                handlerID: handler.handlerID,
                event: DOMEvent()
            )
        )
        let incrementedIndex = try #require(incremented.hydrationIndex)
        let incrementedTextNode = try #require(incremented.commandBatch?.commands.compactMap(textUpdateNode).first)
        let snapshot = try oldBridge.snapshotState()
        let snapshotValue = try #require(snapshot.values.first?.value)
        let incompatibleSnapshot = ClientWasmStateSnapshot(
            schemaHash: "incompatible",
            values: [
                "legacy-component:state:Other.swift:1:1": snapshotValue,
            ]
        )

        WasmBridgeHotReloadStateFixture.text = "After"
        let newBridge = ClientWasmRuntimeBridge<WasmBridgeHotReloadStatefulComponent>(
            componentMount: ClientWasmComponentMount(WasmBridgeHotReloadStatefulComponent.self)
        ) { _ in
            WasmBridgeHotReloadStatefulComponent()
        }

        let response = try newBridge.bootstrap(
            ClientWasmBootstrapRequest(
                hydrationIndex: incrementedIndex,
                location: ClientWasmBootstrapLocation(
                    href: "http://127.0.0.1:8080/storyboard",
                    search: ""
                ),
                mode: .hotReload,
                stateSnapshot: incompatibleSnapshot
            )
        )

        #expect(response.hydrationIndex?.nodes.contains { node in
            node.role == .text && node.text == "After 0"
        } == true)
        #expect(response.commandBatch?.commands.contains { command in
            command == .updateText(node: incrementedTextNode, value: "After 0")
        } == true)
    }

    @Test
    func bridgeRebasesMountedComponentHydrationIndexAfterInsertion() throws {
        let serverArtifact = WasmBridgeMountedListRoot().renderArtifact()
        let serverIndex = serverArtifact.browserHydrationIndex()
        let bridge = ClientWasmRuntimeBridge<WasmBridgeAppendList>(
            componentMount: ClientWasmComponentMount(WasmBridgeAppendList.self)
        ) { _ in
            WasmBridgeAppendList()
        }

        _ = try bridge.bootstrap(
            ClientWasmBootstrapRequest(
                hydrationIndex: serverIndex,
                location: ClientWasmBootstrapLocation(
                    href: "http://127.0.0.1:8080/list",
                    search: ""
                )
            )
        )
        let handler = try #require(serverIndex.handlers.first)

        let firstUpdate = try bridge.dispatch(
            ClientWasmEventRequest(
                handlerID: handler.handlerID,
                event: DOMEvent()
            )
        )
        let firstIndex = try #require(firstUpdate.hydrationIndex)

        #expect(firstUpdate.commandBatch?.commands.contains { command in
            if case .insertHTML = command {
                return true
            }
            return false
        } == true)
        #expect(firstIndex.nodes.contains { node in
            node.role == .text && node.text == "Item 3"
        })
        try assertCommandTargetsResolve(firstUpdate)

        let secondUpdate = try bridge.dispatch(
            ClientWasmEventRequest(
                handlerID: handler.handlerID,
                event: DOMEvent()
            )
        )
        let secondIndex = try #require(secondUpdate.hydrationIndex)

        #expect(secondIndex.nodes.contains { node in
            node.role == .text && node.text == "Item 4"
        })
        try assertCommandTargetsResolve(secondUpdate)
    }

    @Test
    func bridgeRestoresClientEnvironmentSnapshotFromBootstrapIndex() throws {
        let serverArtifact = WasmBridgeEnvironmentReader()
            .environment(\.wasmBridgeValue, "server")
            .renderArtifact()
        let registry = ClientEnvironmentRegistry()
            .registering(WasmBridgeEnvironmentKey.self)
        let bridge = ClientWasmRuntimeBridge<WasmBridgeEnvironmentReader>(
            environmentRegistry: registry
        ) { _ in
            WasmBridgeEnvironmentReader()
        }

        let bootstrap = try bridge.bootstrap(
            ClientWasmBootstrapRequest(
                hydrationIndex: serverArtifact.browserHydrationIndex(),
                location: ClientWasmBootstrapLocation(
                    href: "http://127.0.0.1:8080/environment",
                    search: ""
                )
            )
        )
        let textNode = try #require(bootstrap.hydrationIndex?.nodes.first { node in
            node.role == .text
        })

        #expect(textNode.text == "server")
    }

    @Test
    func bridgeRestoresClientEnvironmentSnapshotsPerComponentPath() throws {
        let serverArtifact = WasmBridgeScopedEnvironmentRoot(
            left: "server-left",
            right: "server-right"
        )
        .renderArtifact()
        let registry = ClientEnvironmentRegistry()
            .registering(WasmBridgeEnvironmentKey.self)
        let bridge = ClientWasmRuntimeBridge<WasmBridgeScopedEnvironmentRoot>(
            environmentRegistry: registry
        ) { _ in
            WasmBridgeScopedEnvironmentRoot(
                left: "client-left",
                right: "client-right"
            )
        }

        let bootstrap = try bridge.bootstrap(
            ClientWasmBootstrapRequest(
                hydrationIndex: serverArtifact.browserHydrationIndex(),
                location: ClientWasmBootstrapLocation(
                    href: "http://127.0.0.1:8080/environment",
                    search: ""
                )
            )
        )
        let textValues = bootstrap.hydrationIndex?.nodes.compactMap { node in
            node.role == .text ? node.text : nil
        } ?? []

        #expect(textValues.contains("server-left"))
        #expect(textValues.contains("server-right"))
        #expect(!textValues.contains("client-left"))
        #expect(!textValues.contains("client-right"))
    }

    private func assertCommandTargetsResolve(_ response: ClientWasmRuntimeResponse) throws {
        let index = try #require(response.hydrationIndex)
        let commands = response.commandBatch?.commands ?? []
        #expect(!commands.isEmpty)
        for id in commands.flatMap(targetNodeIDs) {
            _ = try #require(index.node(id))
        }
    }

    private func targetNodeIDs(for command: BrowserDOMCommand) -> [HTMLNodeID] {
        switch command {
        case .replaceNode(let node, let replacement):
            [node, replacement]
        case .replaceSubtree(let node, _):
            [node]
        case .updateText(let node, _):
            [node]
        case .updateComment(let node, _):
            [node]
        case .updateAttributes(let node, _):
            [node]
        case .setProperty(let node, _, _):
            [node]
        case .insertNode(let parent, _, let node):
            [parent, node]
        case .insertHTML(let parent, _, _):
            [parent]
        case .remove(let parent, _, let node):
            [parent, node]
        case .move(let parent, _, _, _):
            [parent]
        case .moveKeyed(let parent, _, _):
            [parent]
        }
    }

    private func textUpdateNode(_ command: BrowserDOMCommand) -> HTMLNodeID? {
        if case .updateText(let node, _) = command {
            return node
        }
        return nil
    }
}
