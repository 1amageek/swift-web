#if os(WASI)
import JavaScriptKit
import SwiftHTML

public struct JavaScriptKitBrowserDOMHost: BrowserDOMHost {
    public init() {}

    public func apply(
        _ batch: BrowserDOMCommandBatch,
        updatedIndex: BrowserHydrationIndex
    ) {
        JavaScriptKitBrowserRuntime.apply(batch, hydrationIndex: updatedIndex)
    }
}

public enum JavaScriptKitBrowserRuntime {
    public static func installExecutor() {
    }

    public static func apply(
        _ batch: BrowserDOMCommandBatch,
        hydrationIndex: BrowserHydrationIndex
    ) {
        for command in batch.commands {
            apply(command, hydrationIndex: hydrationIndex)
        }
    }

    private static func apply(
        _ command: BrowserDOMCommand,
        hydrationIndex: BrowserHydrationIndex
    ) {
        switch command {
        case .replaceNode(let node, let replacement):
            replaceNode(node, replacement: replacement, hydrationIndex: hydrationIndex)
        case .replaceSubtree(let node, let html):
            replaceSubtree(node, html: html, hydrationIndex: hydrationIndex)
        case .updateText(let node, let value):
            updateText(node, value: value, hydrationIndex: hydrationIndex)
        case .updateComment(let node, let value):
            updateText(node, value: value, hydrationIndex: hydrationIndex)
        case .updateAttributes(let node, let attributes):
            updateAttributes(node, attributes: attributes, hydrationIndex: hydrationIndex)
        case .setProperty(let node, let name, let value):
            setProperty(node, name: name, value: value, hydrationIndex: hydrationIndex)
        case .insertNode(let parent, let index, let node):
            insertNode(parent: parent, index: index, node: node, hydrationIndex: hydrationIndex)
        case .insertHTML(let parent, let index, let html):
            insertHTML(parent: parent, index: index, html: html, hydrationIndex: hydrationIndex)
        case .remove(let parent, let index, let node):
            removeNode(parent: parent, index: index, node: node, hydrationIndex: hydrationIndex)
        case .move(let parent, let from, let to, _):
            moveNode(parent: parent, from: from, to: to, hydrationIndex: hydrationIndex)
        case .moveKeyed(let parent, let key, let to):
            moveKeyedNode(parent: parent, key: key, to: to, hydrationIndex: hydrationIndex)
        }
    }

    private static var document: JSValue {
        JSObject.global.document
    }

    private static func replaceNode(
        _ nodeID: HTMLNodeID,
        replacement replacementID: HTMLNodeID,
        hydrationIndex: BrowserHydrationIndex
    ) {
        guard let node = resolveDOMNode(nodeID, hydrationIndex: hydrationIndex),
              let replacement = resolveDOMNode(replacementID, hydrationIndex: hydrationIndex)
        else {
            return
        }
        _ = node.replaceWith(replacement.cloneNode(true))
    }

    private static func replaceSubtree(
        _ nodeID: HTMLNodeID,
        html: String,
        hydrationIndex: BrowserHydrationIndex
    ) {
        guard let node = resolveDOMNode(nodeID, hydrationIndex: hydrationIndex) else {
            return
        }
        let range = document.createRange()
        _ = range.selectNode(node)
        let fragment = range.createContextualFragment(html)
        _ = node.replaceWith(fragment)
    }

    private static func updateText(
        _ nodeID: HTMLNodeID,
        value: String,
        hydrationIndex: BrowserHydrationIndex
    ) {
        guard let node = resolveDOMNode(nodeID, hydrationIndex: hydrationIndex) else {
            return
        }
        node.textContent = JSValue.string(value)
    }

    private static func updateAttributes(
        _ nodeID: HTMLNodeID,
        attributes: [HTMLAttributeRecord],
        hydrationIndex: BrowserHydrationIndex
    ) {
        guard let node = resolveDOMNode(nodeID, hydrationIndex: hydrationIndex),
              let object = node.object
        else {
            return
        }
        let nodeValue = JSValue.object(object)

        let internalNode = nodeValue.getAttribute("data-swift-node").string
        let internalKey = nodeValue.getAttribute("data-swift-key").string
        let names = Set(attributes.map(\.name))
        let existing = object.attributes
        let count = Int(existing.length.number ?? 0)
        var removable: [String] = []
        for index in 0..<count {
            let attribute = existing[index]
            guard let name = attribute.name.string,
                  name != "data-swift-node",
                  name != "data-swift-key",
                  !names.contains(name)
            else {
                continue
            }
            removable.append(name)
        }
        for name in removable {
            _ = nodeValue.removeAttribute(name)
        }
        for attribute in attributes {
            _ = nodeValue.setAttribute(attribute.name, attribute.value ?? "")
        }
        if let internalNode {
            _ = nodeValue.setAttribute("data-swift-node", internalNode)
        }
        if let internalKey {
            _ = nodeValue.setAttribute("data-swift-key", internalKey)
        }
    }

    private static func setProperty(
        _ nodeID: HTMLNodeID,
        name: String,
        value: String?,
        hydrationIndex: BrowserHydrationIndex
    ) {
        guard let node = resolveDOMNode(nodeID, hydrationIndex: hydrationIndex),
              let object = node.object
        else {
            return
        }
        let nodeValue = JSValue.object(object)

        switch name {
        case "checked", "disabled", "selected":
            let enabled = value == "true"
            object[name] = JSValue.boolean(enabled)
            if enabled {
                _ = nodeValue.setAttribute(name, "")
            } else {
                _ = nodeValue.removeAttribute(name)
            }
        default:
            if let value {
                object[name] = JSValue.string(value)
                _ = nodeValue.setAttribute(name, value)
            } else {
                object[name] = .undefined
                _ = nodeValue.removeAttribute(name)
            }
        }
    }

    private static func insertNode(
        parent parentID: HTMLNodeID,
        index: Int,
        node nodeID: HTMLNodeID,
        hydrationIndex: BrowserHydrationIndex
    ) {
        guard let parent = resolveDOMNode(parentID, hydrationIndex: hydrationIndex),
              let node = resolveDOMNode(nodeID, hydrationIndex: hydrationIndex)
        else {
            return
        }
        _ = parent.insertBefore(node, childNode(parent: parent, index: index) ?? .null)
    }

    private static func insertHTML(
        parent parentID: HTMLNodeID,
        index: Int,
        html: String,
        hydrationIndex: BrowserHydrationIndex
    ) {
        guard let parent = resolveDOMNode(parentID, hydrationIndex: hydrationIndex) else {
            return
        }
        let range = document.createRange()
        _ = range.setStart(parent, index)
        let fragment = range.createContextualFragment(html)
        _ = parent.insertBefore(fragment, childNode(parent: parent, index: index) ?? .null)
    }

    private static func removeNode(
        parent parentID: HTMLNodeID,
        index: Int,
        node nodeID: HTMLNodeID,
        hydrationIndex: BrowserHydrationIndex
    ) {
        guard let parent = resolveDOMNode(parentID, hydrationIndex: hydrationIndex) else {
            return
        }
        let node = resolveDOMNode(nodeID, hydrationIndex: hydrationIndex) ?? childNode(parent: parent, index: index)
        guard let node else {
            return
        }
        _ = parent.removeChild(node)
    }

    private static func moveNode(
        parent parentID: HTMLNodeID,
        from sourceIndex: Int,
        to destinationIndex: Int,
        hydrationIndex: BrowserHydrationIndex
    ) {
        guard let parent = resolveDOMNode(parentID, hydrationIndex: hydrationIndex),
              let node = childNode(parent: parent, index: sourceIndex)
        else {
            return
        }
        _ = parent.insertBefore(node, childNode(parent: parent, index: destinationIndex) ?? .null)
    }

    private static func moveKeyedNode(
        parent parentID: HTMLNodeID,
        key: Key,
        to destinationIndex: Int,
        hydrationIndex: BrowserHydrationIndex
    ) {
        guard let parent = resolveDOMNode(parentID, hydrationIndex: hydrationIndex) else {
            return
        }
        let node = document.querySelector("[data-swift-key=\"\(cssEscape(key.identity))\"]")
        if node.isNull || node.isUndefined {
            return
        }
        _ = parent.insertBefore(node, childNode(parent: parent, index: destinationIndex) ?? .null)
    }

    private static func childNode(parent: JSValue, index: Int) -> JSValue? {
        let value = parent.childNodes[index]
        return value.isNull || value.isUndefined ? nil : value
    }

    private static func resolveDOMNode(
        _ nodeID: HTMLNodeID,
        hydrationIndex: BrowserHydrationIndex
    ) -> JSValue? {
        let direct = document.querySelector("[data-swift-node=\"\(nodeID.rawValue)\"]")
        if !direct.isNull && !direct.isUndefined {
            return direct
        }
        guard let record = hydrationIndex.node(nodeID),
              record.role == .text || record.role == .comment || record.role == .placeholder
        else {
            return nil
        }
        return resolveRenderedChild(record, hydrationIndex: hydrationIndex)
    }

    private static func resolveRenderedChild(
        _ record: BrowserHydrationNodeRecord,
        hydrationIndex: BrowserHydrationIndex
    ) -> JSValue? {
        guard let parentID = record.parentID,
              let parent = resolveDOMNode(parentID, hydrationIndex: hydrationIndex),
              let parentRecord = hydrationIndex.node(parentID)
        else {
            return nil
        }

        var domIndex = 0
        for childID in parentRecord.childIDs {
            if childID == record.id {
                return childNode(parent: parent, index: domIndex)
            }
            domIndex += renderedNodeCount(childID, hydrationIndex: hydrationIndex)
        }
        return nil
    }

    private static func renderedNodeCount(
        _ nodeID: HTMLNodeID,
        hydrationIndex: BrowserHydrationIndex
    ) -> Int {
        guard let record = hydrationIndex.node(nodeID) else {
            return 0
        }
        switch record.role {
        case .fragment, .document:
            return record.childIDs.reduce(0) { total, childID in
                total + renderedNodeCount(childID, hydrationIndex: hydrationIndex)
            }
        case .component, .serverSlot:
            return 2 + record.childIDs.reduce(0) { total, childID in
                total + renderedNodeCount(childID, hydrationIndex: hydrationIndex)
            }
        default:
            return 1
        }
    }

    private static func cssEscape(_ value: String) -> String {
        value
            .replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "\"", with: "\\\"")
    }
}
#endif
