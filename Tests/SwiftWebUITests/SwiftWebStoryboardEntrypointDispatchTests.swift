import Foundation
import SwiftHTML
import SwiftWebUIRuntime
import Testing

@testable import SwiftWebStoryboard

/// Reproduces the real WASM entrypoint flow against the actual catalog page:
/// bootstrap every registered island against the page's hydration index (the
/// entrypoint threads the index through each bootstrap), then dispatch a
/// handler inside the detail island. The returned index must stay free of
/// duplicate component and node IDs — the entrypoint rebuilds its handler
/// index with `Dictionary(uniqueKeysWithValues:)`, so one duplicate kills
/// every later event dispatch in the browser.
@Suite
struct SwiftWebStoryboardEntrypointDispatchTests {
    @Test
    func catalogIslandDispatchKeepsHydrationIndexDuplicateFree() throws {
        let location = ClientRuntimeBootstrapLocation(
            href: "http://127.0.0.1:3001/storyboard/asyncimage",
            search: ""
        )
        let artifact = StoryboardCatalog(initialSelection: "asyncimage").renderArtifact()
        var currentIndex = artifact.browserHydrationIndex()

        let quickOpenRecord = try #require(currentIndex.components.first { component in
            component.typeName == String(reflecting: StoryboardQuickOpen.self)
        })
        let islandRecord = try #require(currentIndex.components.first { component in
            component.typeName == String(reflecting: StoryboardDetailIsland.self)
        })

        let quickOpenBridge = ClientRuntimeBridge<StoryboardQuickOpen>(
            environmentRegistry: .swiftWebUI,
            componentMount: ClientComponentMount(
                typeName: quickOpenRecord.typeName,
                componentID: quickOpenRecord.id
            )
        ) { _ in
            StoryboardQuickOpen()
        }
        let islandBridge = ClientRuntimeBridge<StoryboardDetailIsland>(
            environmentRegistry: .swiftWebUI,
            componentMount: ClientComponentMount(
                typeName: islandRecord.typeName,
                componentID: islandRecord.id
            )
        ) { request in
            try StoryboardDetailIsland(bootstrap: request)
        }

        let quickOpenResponse = try quickOpenBridge.bootstrap(
            ClientRuntimeBootstrapRequest(hydrationIndex: currentIndex, location: location)
        )
        currentIndex = quickOpenResponse.hydrationIndex ?? currentIndex
        let islandResponse = try islandBridge.bootstrap(
            ClientRuntimeBootstrapRequest(hydrationIndex: currentIndex, location: location)
        )
        currentIndex = islandResponse.hydrationIndex ?? currentIndex

        try assertDuplicateFree(currentIndex, phase: "bootstrap")

        let islandNodeIDs = descendantNodeIDs(of: islandRecord.nodeID, in: currentIndex)
        let islandHandlers = currentIndex.handlers.filter { binding in
            islandNodeIDs.contains(binding.nodeID)
        }
        #expect(!islandHandlers.isEmpty, "expected knob handlers inside the detail island")

        var dispatchIndex = currentIndex
        for (round, handler) in islandHandlers.prefix(3).enumerated() {
            let response = try islandBridge.dispatch(
                ClientRuntimeEventRequest(handlerID: handler.handlerID, event: DOMEvent())
            )
            dispatchIndex = try #require(response.hydrationIndex)
            try assertDuplicateFree(dispatchIndex, phase: "dispatch #\(round)")
        }
    }

    private func assertDuplicateFree(_ index: BrowserHydrationIndex, phase: String) throws {
        let componentIDs = index.components.map(\.id.rawValue)
        let duplicateComponentIDs = duplicates(in: componentIDs)
        #expect(
            duplicateComponentIDs.isEmpty,
            "duplicate component IDs after \(phase): \(duplicateComponentIDs)"
        )

        let nodeIDs = index.nodes.map(\.id.rawValue)
        let duplicateNodeIDs = duplicates(in: nodeIDs)
        #expect(
            duplicateNodeIDs.isEmpty,
            "duplicate node IDs after \(phase): \(duplicateNodeIDs)"
        )

        let componentNodeIDs = index.components.map(\.nodeID.rawValue)
        let duplicateComponentNodes = duplicates(in: componentNodeIDs)
        #expect(
            duplicateComponentNodes.isEmpty,
            "multiple components share a node after \(phase): \(duplicateComponentNodes)"
        )
    }

    private func duplicates<Value: Hashable>(in values: [Value]) -> [Value] {
        var seen = Set<Value>()
        var duplicated = Set<Value>()
        for value in values where !seen.insert(value).inserted {
            duplicated.insert(value)
        }
        return Array(duplicated)
    }

    private func descendantNodeIDs(of rootID: HTMLNodeID, in index: BrowserHydrationIndex) -> Set<HTMLNodeID> {
        var result = Set<HTMLNodeID>()
        func walk(_ nodeID: HTMLNodeID) {
            guard result.insert(nodeID).inserted, let node = index.node(nodeID) else {
                return
            }
            for childID in node.childIDs {
                walk(childID)
            }
        }
        walk(rootID)
        return result
    }
}
