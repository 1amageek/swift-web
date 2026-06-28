import Foundation
import SwiftHTML
import SwiftWebActors
import SwiftWebUIRuntime
import Synchronization
import Testing
import SwiftWebUI

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

private struct WasmBridgeAnimatedCounter: ClientComponent, Sendable {
    @State private var value = 0

    var body: some HTML {
        button(.type(ButtonType.button), .onClick {
            withAnimation(.easeInOut(duration: 0.3)) {
                value += 1
            }
        }) {
            "\(value)"
        }
    }
}

/// Records the animation the bridge hands to the DOM host, so the end-to-end seam
/// (handler → Transaction → host.apply(animation:)) can be asserted on the host
/// (the production JS host is WASI-only and unobservable from macOS tests).
private final class AnimationRecordingHost: BrowserDOMHost {
    struct Record: Sendable {
        var applyCount = 0
        var lastAnimation: TransactionAnimation?
    }

    let state = Mutex(Record())

    func apply(_ batch: BrowserDOMCommandBatch, currentIndex: BrowserHydrationIndex) {
        state.withLock {
            $0.applyCount += 1
            $0.lastAnimation = nil
        }
    }

    func apply(
        _ batch: BrowserDOMCommandBatch,
        currentIndex: BrowserHydrationIndex,
        animation: TransactionAnimation?
    ) {
        state.withLock {
            $0.applyCount += 1
            $0.lastAnimation = animation
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

private struct WasmBridgeProperty: Identifiable, Sendable {
    let id: String
    let name: String
    let values: String
}

private struct WasmBridgePropertyRow: Component, Sendable {
    let property: WasmBridgeProperty

    var body: some HTML {
        article {
            h3 {
                property.name
            }
            code {
                property.values
            }
        }
    }
}

private struct WasmBridgePropertySelectionOwner: ClientComponent, Sendable {
    @State private var selection = "typography"

    private var properties: [WasmBridgeProperty] {
        if selection == "button" {
            return [
                WasmBridgeProperty(id: "title", name: "title", values: "String"),
                WasmBridgeProperty(id: "prominence", name: "prominence", values: ".primary / .secondary"),
                WasmBridgeProperty(id: "action", name: "action", values: "closure / Action"),
            ]
        }
        return [
            WasmBridgeProperty(id: "level", name: "level", values: ".page / .section"),
            WasmBridgeProperty(id: "as", name: "as", values: ".p / .small"),
            WasmBridgeProperty(id: "tone", name: "tone", values: ".normal / .muted"),
        ]
    }

    var body: some HTML {
        button(.type(ButtonType.button), .onClick {
            selection = "button"
        }) {
            "Button"
        }
        section {
            ForEach(properties) { property in
                WasmBridgePropertyRow(property: property)
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

private struct WasmBridgeReplacementBefore: Component, Sendable {
    var body: some HTML {
        section {
            p {
                "Before replacement"
            }
        }
    }
}

private struct WasmBridgeReplacementAfter: Component, Sendable {
    var body: some HTML {
        section {
            p {
                "After replacement"
            }
        }
    }
}

private struct WasmBridgeComponentReplacement: ClientComponent, Sendable {
    @State private var showsAfter = false

    var body: some HTML {
        button(.type(ButtonType.button), .onClick {
            showsAfter = true
        }) {
            "Switch"
        }
        if showsAfter {
            WasmBridgeReplacementAfter()
        } else {
            WasmBridgeReplacementBefore()
        }
    }
}

private struct WasmBridgeSelectionOwner: ClientComponent, Sendable {
    @State private var selection = "typography"

    @HTMLBuilder
    var body: some HTML {
        button(.type(ButtonType.button), .onClick {
            selection = "color"
        }) {
            "Color & tint"
        }
        h1 {
            selection
        }
        WasmBridgeSelectionChild(selection: selection)
    }
}

private struct WasmBridgeSelectionChild: Component, Sendable {
    let selection: String

    @HTMLBuilder
    var body: some HTML {
        switch selection {
        case "color":
            div {
                button {
                    "Accent"
                }
                button {
                    "Danger"
                }
            }
        default:
            div {
                h2 {
                    "Page heading"
                }
                p {
                    "Body copy"
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

private struct WasmBridgeMountedReplacementRoot: Component, Sendable {
    var body: some HTML {
        div {
            span {
                "server prefix"
            }
            WasmBridgeComponentReplacement()
        }
    }
}

private struct WasmBridgeMountedSelectionRoot: Component, Sendable {
    var body: some HTML {
        div {
            span {
                "server prefix"
            }
            WasmBridgeSelectionOwner()
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

private struct WasmBridgeMountedPropertySelectionRoot: Component, Sendable {
    var body: some HTML {
        div {
            span {
                "server prefix"
            }
            WasmBridgePropertySelectionOwner()
        }
    }
}

@Suite(.serialized)
struct SwiftWebUIRuntimeClientRuntimeBridgeTests {
    @Test
    func bootstrapRequestCodableSupportsNavigationMode() throws {
        let request = ClientRuntimeBootstrapRequest(
            hydrationIndex: .empty,
            location: ClientRuntimeBootstrapLocation(
                href: "http://127.0.0.1:8080/storyboard/style",
                search: ""
            ),
            mode: .navigation,
            actorBindings: [
                SwiftWebActorBindingRecord(contractKey: "CounterService", actorID: "counter-1"),
            ]
        )

        let data = try JSONEncoder().encode(request)
        let decoded = try JSONDecoder().decode(ClientRuntimeBootstrapRequest.self, from: data)

        #expect(decoded.mode == .navigation)
        #expect(decoded.actorBindings == [
            SwiftWebActorBindingRecord(contractKey: "CounterService", actorID: "counter-1"),
        ])
        #expect(String(decoding: data, as: UTF8.self).contains("\"mode\":\"navigation\""))
        #expect(String(decoding: data, as: UTF8.self).contains("\"actorBindings\""))
    }

    @Test
    func bridgeBootstrapsAndDispatchesClientStateWithoutServerSession() throws {
        let bridge = ClientRuntimeBridge<WasmBridgeCounter> { _ in
            WasmBridgeCounter()
        }

        let bootstrap = try bridge.bootstrap(
            ClientRuntimeBootstrapRequest(
                hydrationIndex: .empty,
                location: ClientRuntimeBootstrapLocation(
                    href: "http://127.0.0.1:8080/counter?server=8",
                    search: "?server=8"
                )
            )
        )
        let handler = try #require(bootstrap.hydrationIndex?.handlers.first)
        let update = try bridge.dispatch(
            ClientRuntimeEventRequest(
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
    func dispatchWithAnimationDeliversTheAnimationToTheDOMHost() throws {
        let host = AnimationRecordingHost()
        let bridge = ClientRuntimeBridge<WasmBridgeAnimatedCounter>(domHost: host) { _ in
            WasmBridgeAnimatedCounter()
        }
        let bootstrap = try bridge.bootstrap(
            ClientRuntimeBootstrapRequest(
                hydrationIndex: .empty,
                location: ClientRuntimeBootstrapLocation(
                    href: "http://127.0.0.1:8080/anim",
                    search: ""
                )
            )
        )
        let handler = try #require(bootstrap.hydrationIndex?.handlers.first)
        _ = try bridge.dispatch(
            ClientRuntimeEventRequest(handlerID: handler.handlerID, event: DOMEvent())
        )
        let record = host.state.withLock { $0 }
        #expect(record.applyCount == 1)
        #expect(record.lastAnimation?.css == "0.3s cubic-bezier(0.42, 0, 0.58, 1) 0s")
        #expect(record.lastAnimation?.durationMilliseconds == 300)
    }

    @Test
    func dispatchWithoutWithAnimationDeliversNoAnimationToTheDOMHost() throws {
        let host = AnimationRecordingHost()
        let bridge = ClientRuntimeBridge<WasmBridgeCounter>(domHost: host) { _ in
            WasmBridgeCounter()
        }
        let bootstrap = try bridge.bootstrap(
            ClientRuntimeBootstrapRequest(
                hydrationIndex: .empty,
                location: ClientRuntimeBootstrapLocation(
                    href: "http://127.0.0.1:8080/plain",
                    search: ""
                )
            )
        )
        let handler = try #require(bootstrap.hydrationIndex?.handlers.first)
        _ = try bridge.dispatch(
            ClientRuntimeEventRequest(handlerID: handler.handlerID, event: DOMEvent())
        )
        let record = host.state.withLock { $0 }
        #expect(record.applyCount == 1)
        #expect(record.lastAnimation == nil)
    }

    @Test
    func bridgeCanMountAClientComponentInsideAServerRenderedPage() throws {
        let serverArtifact = WasmBridgeMountedRoot().renderArtifact()
        let serverIndex = serverArtifact.browserHydrationIndex()
        let serverValueNode = try #require(serverIndex.nodes.first { node in
            node.role == .text && node.text == "0"
        })
        let bridge = ClientRuntimeBridge<WasmBridgeCounter>(
            componentMount: ClientComponentMount(WasmBridgeCounter.self)
        ) { _ in
            WasmBridgeCounter()
        }

        let bootstrap = try bridge.bootstrap(
            ClientRuntimeBootstrapRequest(
                hydrationIndex: serverIndex,
                location: ClientRuntimeBootstrapLocation(
                    href: "http://127.0.0.1:8080/counter",
                    search: ""
                )
            )
        )
        let handler = try #require(serverIndex.handlers.first)
        let update = try bridge.dispatch(
            ClientRuntimeEventRequest(
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
        let bridge = ClientRuntimeBridge<WasmBridgeCounter>(
            componentMount: ClientComponentMount(WasmBridgeCounter.self)
        ) { _ in
            WasmBridgeCounter()
        }

        _ = try bridge.bootstrap(
            ClientRuntimeBootstrapRequest(
                hydrationIndex: serverIndex,
                location: ClientRuntimeBootstrapLocation(
                    href: "http://127.0.0.1:8080/counter",
                    search: ""
                )
            )
        )
        let firstUpdate = try bridge.dispatch(
            ClientRuntimeEventRequest(
                handlerID: counterHandler.handlerID,
                event: DOMEvent()
            )
        )
        let secondUpdate = try bridge.dispatch(
            ClientRuntimeEventRequest(
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
    func bridgeRebasesReplacementSubtreeHydrationMarkersForMountedComponent() throws {
        let serverArtifact = WasmBridgeMountedReplacementRoot().renderArtifact()
        let serverIndex = serverArtifact.browserHydrationIndex()
        let component = try #require(serverIndex.components.first { component in
            component.typeName == String(reflecting: WasmBridgeComponentReplacement.self)
        })
        let handler = try #require(serverIndex.handlers.first { binding in
            binding.componentID == component.id
        })
        let bridge = ClientRuntimeBridge<WasmBridgeComponentReplacement>(
            componentMount: ClientComponentMount(WasmBridgeComponentReplacement.self)
        ) { _ in
            WasmBridgeComponentReplacement()
        }

        _ = try bridge.bootstrap(
            ClientRuntimeBootstrapRequest(
                hydrationIndex: serverIndex,
                location: ClientRuntimeBootstrapLocation(
                    href: "http://127.0.0.1:8080/replacement",
                    search: ""
                )
            )
        )
        let update = try bridge.dispatch(
            ClientRuntimeEventRequest(
                handlerID: handler.handlerID,
                event: DOMEvent()
            )
        )
        let nextIndex = try #require(update.hydrationIndex)
        let replacement = try #require(update.commandBatch?.commands.compactMap(replacementSubtree).first { item in
            item.html.contains("After replacement")
        })
        let afterText = try #require(nextIndex.nodes.first { node in
            node.role == .text && node.text == "After replacement"
        })
        let afterParent = try #require(afterText.parentID)

        #expect(nextIndex.node(replacement.node)?.role == .component)
        #expect(replacement.html.contains("data-node=\"\(afterParent.rawValue)\""))
        try assertCommandTargetsResolve(update)
    }

    @Test
    func bridgeRebasesNestedChildComponentConditionalReplacement() throws {
        let serverArtifact = WasmBridgeMountedSelectionRoot().renderArtifact()
        let serverIndex = serverArtifact.browserHydrationIndex()
        let component = try #require(serverIndex.components.first { component in
            component.typeName == String(reflecting: WasmBridgeSelectionOwner.self)
        })
        let handler = try #require(serverIndex.handlers.first { binding in
            binding.componentID == component.id
        })
        let bridge = ClientRuntimeBridge<WasmBridgeSelectionOwner>(
            componentMount: ClientComponentMount(WasmBridgeSelectionOwner.self)
        ) { _ in
            WasmBridgeSelectionOwner()
        }

        _ = try bridge.bootstrap(
            ClientRuntimeBootstrapRequest(
                hydrationIndex: serverIndex,
                location: ClientRuntimeBootstrapLocation(
                    href: "http://127.0.0.1:8080/storyboard",
                    search: ""
                )
            )
        )
        let update = try bridge.dispatch(
            ClientRuntimeEventRequest(
                handlerID: handler.handlerID,
                event: DOMEvent()
            )
        )
        let nextIndex = try #require(update.hydrationIndex)
        let replacementHTML = (update.commandBatch?.commands ?? []).compactMap(replacementSubtree).map(\.html).joined()

        #expect(nextIndex.nodes.contains { node in
            node.role == .text && node.text == "Accent"
        })
        #expect(nextIndex.nodes.contains { node in
            node.role == .text && node.text == "Danger"
        })
        #expect(!nextIndex.nodes.contains { node in
            node.role == .text && node.text == "Page heading"
        })
        #expect(replacementHTML.contains("Accent"))
        #expect(replacementHTML.contains("Danger"))
        try assertCommandTargetsResolve(update, currentIndex: serverIndex)
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
        let bridge = ClientRuntimeBridge<WasmBridgeHotReloadComponent>(
            componentMount: ClientComponentMount(WasmBridgeHotReloadComponent.self)
        ) { _ in
            WasmBridgeHotReloadComponent()
        }

        let response = try bridge.bootstrap(
            ClientRuntimeBootstrapRequest(
                hydrationIndex: serverIndex,
                location: ClientRuntimeBootstrapLocation(
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
        let bridge = ClientRuntimeBridge<WasmBridgeHotReloadStructuralComponent>(
            componentMount: ClientComponentMount(WasmBridgeHotReloadStructuralComponent.self)
        ) { _ in
            WasmBridgeHotReloadStructuralComponent()
        }

        let response = try bridge.bootstrap(
            ClientRuntimeBootstrapRequest(
                hydrationIndex: serverIndex,
                location: ClientRuntimeBootstrapLocation(
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
        let oldBridge = ClientRuntimeBridge<WasmBridgeHotReloadStatefulComponent>(
            componentMount: ClientComponentMount(WasmBridgeHotReloadStatefulComponent.self)
        ) { _ in
            WasmBridgeHotReloadStatefulComponent()
        }

        _ = try oldBridge.bootstrap(
            ClientRuntimeBootstrapRequest(
                hydrationIndex: serverIndex,
                location: ClientRuntimeBootstrapLocation(
                    href: "http://127.0.0.1:8080/storyboard",
                    search: ""
                )
            )
        )
        let handler = try #require(serverIndex.handlers.first)
        let incremented = try oldBridge.dispatch(
            ClientRuntimeEventRequest(
                handlerID: handler.handlerID,
                event: DOMEvent()
            )
        )
        let incrementedIndex = try #require(incremented.hydrationIndex)
        let incrementedTextNode = try #require(incremented.commandBatch?.commands.compactMap(textUpdateNode).first)
        let snapshot = try oldBridge.snapshotState()

        WasmBridgeHotReloadStateFixture.text = "After"
        let newBridge = ClientRuntimeBridge<WasmBridgeHotReloadStatefulComponent>(
            componentMount: ClientComponentMount(WasmBridgeHotReloadStatefulComponent.self)
        ) { _ in
            WasmBridgeHotReloadStatefulComponent()
        }

        let response = try newBridge.bootstrap(
            ClientRuntimeBootstrapRequest(
                hydrationIndex: incrementedIndex,
                location: ClientRuntimeBootstrapLocation(
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
        let oldBridge = ClientRuntimeBridge<WasmBridgeHotReloadStatefulComponent>(
            componentMount: ClientComponentMount(WasmBridgeHotReloadStatefulComponent.self)
        ) { _ in
            WasmBridgeHotReloadStatefulComponent()
        }

        _ = try oldBridge.bootstrap(
            ClientRuntimeBootstrapRequest(
                hydrationIndex: serverIndex,
                location: ClientRuntimeBootstrapLocation(
                    href: "http://127.0.0.1:8080/storyboard",
                    search: ""
                )
            )
        )
        let handler = try #require(serverIndex.handlers.first)
        let incremented = try oldBridge.dispatch(
            ClientRuntimeEventRequest(
                handlerID: handler.handlerID,
                event: DOMEvent()
            )
        )
        let incrementedIndex = try #require(incremented.hydrationIndex)
        let incrementedTextNode = try #require(incremented.commandBatch?.commands.compactMap(textUpdateNode).first)
        let snapshot = try oldBridge.snapshotState()
        let snapshotWithChangedComponentID = ClientRuntimeStateSnapshot(
            schemaHash: "legacy-component-id",
            values: Dictionary(uniqueKeysWithValues: snapshot.values.map { key, value in
                let sourceSuffix = key.range(of: ":state:").map { range in
                    String(key[range.lowerBound...])
                } ?? key
                return ("legacy-component\(sourceSuffix)", value)
            })
        )

        WasmBridgeHotReloadStateFixture.text = "After"
        let newBridge = ClientRuntimeBridge<WasmBridgeHotReloadStatefulComponent>(
            componentMount: ClientComponentMount(WasmBridgeHotReloadStatefulComponent.self)
        ) { _ in
            WasmBridgeHotReloadStatefulComponent()
        }

        let response = try newBridge.bootstrap(
            ClientRuntimeBootstrapRequest(
                hydrationIndex: incrementedIndex,
                location: ClientRuntimeBootstrapLocation(
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
        let oldBridge = ClientRuntimeBridge<WasmBridgeHotReloadStatefulComponent>(
            componentMount: ClientComponentMount(WasmBridgeHotReloadStatefulComponent.self)
        ) { _ in
            WasmBridgeHotReloadStatefulComponent()
        }

        _ = try oldBridge.bootstrap(
            ClientRuntimeBootstrapRequest(
                hydrationIndex: serverIndex,
                location: ClientRuntimeBootstrapLocation(
                    href: "http://127.0.0.1:8080/storyboard",
                    search: ""
                )
            )
        )
        let handler = try #require(serverIndex.handlers.first)
        let incremented = try oldBridge.dispatch(
            ClientRuntimeEventRequest(
                handlerID: handler.handlerID,
                event: DOMEvent()
            )
        )
        let incrementedIndex = try #require(incremented.hydrationIndex)
        let incrementedTextNode = try #require(incremented.commandBatch?.commands.compactMap(textUpdateNode).first)
        let snapshot = try oldBridge.snapshotState()
        let snapshotValue = try #require(snapshot.values.first?.value)
        let incompatibleSnapshot = ClientRuntimeStateSnapshot(
            schemaHash: "incompatible",
            values: [
                "legacy-component:state:Other.swift:1:1": snapshotValue,
            ]
        )

        WasmBridgeHotReloadStateFixture.text = "After"
        let newBridge = ClientRuntimeBridge<WasmBridgeHotReloadStatefulComponent>(
            componentMount: ClientComponentMount(WasmBridgeHotReloadStatefulComponent.self)
        ) { _ in
            WasmBridgeHotReloadStatefulComponent()
        }

        let response = try newBridge.bootstrap(
            ClientRuntimeBootstrapRequest(
                hydrationIndex: incrementedIndex,
                location: ClientRuntimeBootstrapLocation(
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
        let bridge = ClientRuntimeBridge<WasmBridgeAppendList>(
            componentMount: ClientComponentMount(WasmBridgeAppendList.self)
        ) { _ in
            WasmBridgeAppendList()
        }

        _ = try bridge.bootstrap(
            ClientRuntimeBootstrapRequest(
                hydrationIndex: serverIndex,
                location: ClientRuntimeBootstrapLocation(
                    href: "http://127.0.0.1:8080/list",
                    search: ""
                )
            )
        )
        let handler = try #require(serverIndex.handlers.first)

        let firstUpdate = try bridge.dispatch(
            ClientRuntimeEventRequest(
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
            ClientRuntimeEventRequest(
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
    func bridgeRebasesKeyedForEachComponentRowsAcrossDisjointKeys() throws {
        let serverArtifact = WasmBridgeMountedPropertySelectionRoot().renderArtifact()
        let serverIndex = serverArtifact.browserHydrationIndex()
        let component = try #require(serverIndex.components.first { component in
            component.typeName == String(reflecting: WasmBridgePropertySelectionOwner.self)
        })
        let handler = try #require(serverIndex.handlers.first { binding in
            binding.componentID == component.id
        })
        let bridge = ClientRuntimeBridge<WasmBridgePropertySelectionOwner>(
            componentMount: ClientComponentMount(WasmBridgePropertySelectionOwner.self)
        ) { _ in
            WasmBridgePropertySelectionOwner()
        }

        _ = try bridge.bootstrap(
            ClientRuntimeBootstrapRequest(
                hydrationIndex: serverIndex,
                location: ClientRuntimeBootstrapLocation(
                    href: "http://127.0.0.1:8080/storyboard",
                    search: ""
                )
            )
        )
        let update = try bridge.dispatch(
            ClientRuntimeEventRequest(
                handlerID: handler.handlerID,
                event: DOMEvent()
            )
        )
        let nextIndex = try #require(update.hydrationIndex)
        let commands = update.commandBatch?.commands ?? []

        #expect(nextIndex.nodes.contains { node in
            node.role == .text && node.text == "title"
        })
        #expect(nextIndex.nodes.contains { node in
            node.role == .text && node.text == "prominence"
        })
        #expect(nextIndex.nodes.contains { node in
            node.role == .text && node.text == "action"
        })
        #expect(!nextIndex.nodes.contains { node in
            node.role == .text && node.text == "level"
        })
        #expect(commands.contains { command in
            if case .remove(let parent, _, _) = command {
                return serverIndex.node(parent)?.role == .fragment
            }
            return false
        })
        #expect(commands.contains { command in
            if case .insertHTML(let parent, _, let html) = command {
                return serverIndex.node(parent)?.role == .fragment && html.contains("title")
            }
            return false
        })
        try assertCommandTargetsResolve(update, currentIndex: serverIndex)
    }

    @Test
    func bridgeRestoresClientEnvironmentSnapshotFromBootstrapIndex() throws {
        let serverArtifact = WasmBridgeEnvironmentReader()
            .environment(\.wasmBridgeValue, "server")
            .renderArtifact()
        let registry = ClientEnvironmentRegistry()
            .registering(WasmBridgeEnvironmentKey.self)
        let bridge = ClientRuntimeBridge<WasmBridgeEnvironmentReader>(
            environmentRegistry: registry
        ) { _ in
            WasmBridgeEnvironmentReader()
        }

        let bootstrap = try bridge.bootstrap(
            ClientRuntimeBootstrapRequest(
                hydrationIndex: serverArtifact.browserHydrationIndex(),
                location: ClientRuntimeBootstrapLocation(
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
        let bridge = ClientRuntimeBridge<WasmBridgeScopedEnvironmentRoot>(
            environmentRegistry: registry
        ) { _ in
            WasmBridgeScopedEnvironmentRoot(
                left: "client-left",
                right: "client-right"
            )
        }

        let bootstrap = try bridge.bootstrap(
            ClientRuntimeBootstrapRequest(
                hydrationIndex: serverArtifact.browserHydrationIndex(),
                location: ClientRuntimeBootstrapLocation(
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

    private func assertCommandTargetsResolve(
        _ response: ClientRuntimeResponse,
        currentIndex: BrowserHydrationIndex? = nil
    ) throws {
        let index = try #require(response.hydrationIndex)
        let commands = response.commandBatch?.commands ?? []
        #expect(!commands.isEmpty)
        for id in commands.flatMap(targetNodeIDs) {
            #expect(index.node(id) != nil || currentIndex?.node(id) != nil)
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

    private func replacementSubtree(_ command: BrowserDOMCommand) -> (node: HTMLNodeID, html: String)? {
        if case .replaceSubtree(let node, let html) = command {
            return (node, html)
        }
        return nil
    }
}
