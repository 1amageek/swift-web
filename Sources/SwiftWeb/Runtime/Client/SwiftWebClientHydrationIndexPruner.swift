import SwiftHTML

enum SwiftWebClientHydrationIndexPruner {
    static func prune(_ index: BrowserHydrationIndex) -> BrowserHydrationIndex {
        guard !index.components.isEmpty else {
            return .empty
        }

        let nodesByID = Dictionary(uniqueKeysWithValues: index.nodes.map { ($0.id, $0) })
        var keptNodeIDs: Set<HTMLNodeID> = []

        func keepSubtree(from nodeID: HTMLNodeID) {
            guard keptNodeIDs.insert(nodeID).inserted,
                  let node = nodesByID[nodeID]
            else {
                return
            }

            for childID in node.childIDs {
                keepSubtree(from: childID)
            }
        }

        for component in index.components {
            keepSubtree(from: component.nodeID)
        }

        guard !keptNodeIDs.isEmpty else {
            return .empty
        }

        let nodes = index.nodes
            .filter { keptNodeIDs.contains($0.id) }
            .map { node in
                BrowserHydrationNodeRecord(
                    id: node.id,
                    parentID: node.parentID.flatMap { keptNodeIDs.contains($0) ? $0 : nil },
                    childIDs: node.childIDs.filter { keptNodeIDs.contains($0) },
                    role: node.role,
                    name: node.name,
                    text: node.text,
                    componentID: node.componentID,
                    serverSlotID: node.serverSlotID,
                    attributes: node.attributes,
                    eventBindings: node.eventBindings.filter { keptNodeIDs.contains($0.nodeID) },
                    key: node.key,
                    fingerprint: node.fingerprint
                )
            }

        let components = index.components.filter { keptNodeIDs.contains($0.nodeID) }
        let componentIDs = Set(components.map(\.id))
        let serverSlots = index.serverSlots.filter { slot in
            componentIDs.contains(slot.ownerComponentID) || keptNodeIDs.contains(slot.nodeID)
        }
        let handlers = index.handlers.filter { keptNodeIDs.contains($0.nodeID) }
        let rootID = keptNodeIDs.contains(index.rootID)
            ? index.rootID
            : components.first?.nodeID ?? nodes.first?.id ?? HTMLNodeID(0)

        return BrowserHydrationIndex(
            rootID: rootID,
            nodes: nodes,
            components: components,
            serverSlots: serverSlots,
            handlers: handlers
        )
    }
}
