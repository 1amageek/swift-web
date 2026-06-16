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

@Suite
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
}
