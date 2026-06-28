#if os(WASI)
#if canImport(FoundationEssentials)
import FoundationEssentials
#elseif canImport(Foundation)
import Foundation
#endif
import JavaScriptKit
import SwiftHTML
import Synchronization

public struct JavaScriptKitBrowserDOMHost: BrowserDOMHost {
    public init() {}

    public func apply(
        _ batch: BrowserDOMCommandBatch,
        currentIndex: BrowserHydrationIndex
    ) {
        JavaScriptKitBrowserRuntime.apply(batch, hydrationIndex: currentIndex)
    }

    public func apply(
        _ batch: BrowserDOMCommandBatch,
        currentIndex: BrowserHydrationIndex,
        animation: TransactionAnimation?
    ) {
        JavaScriptKitBrowserRuntime.apply(batch, hydrationIndex: currentIndex, animation: animation)
    }
}

public enum JavaScriptKitBrowserRuntime {
    public static func installExecutor() {
    }

    // Atomic class names already injected into <style id="swui-atomic">, so each rule
    // is added once across re-renders. Single-threaded (WASI), but Mutex keeps it
    // Sendable-correct.
    private static let injectedAtomicClasses = Mutex<Set<String>>([])

    /// Append not-yet-injected atomic rules into the live `<style id="swui-atomic">`,
    /// so a class produced by a client re-render (e.g. a new arbitrary value from a
    /// control change) has its rule present in the document.
    public static func flushAtomicRules(_ rules: [(className: String, body: String)]) {
        let element = atomicStyleElement()
        let existing = element.textContent.string ?? ""
        let fresh = injectedAtomicClasses.withLock { injected in
            rules.filter { rule in
                guard !existing.contains(".\(rule.className) ") else {
                    injected.insert(rule.className)
                    return false
                }
                return injected.insert(rule.className).inserted
            }
        }
        guard !fresh.isEmpty else { return }
        let css = fresh.map { ".\($0.className) { \($0.body) }" }.joined()
        element.textContent = .string(existing + css)
    }

    private static func atomicStyleElement() -> JSObject {
        if let element = document.getElementById("swui-atomic").object {
            return element
        }
        let element = document.createElement("style").object!
        // JSObject dynamic methods are optional callables in the JavaScriptKit fork.
        _ = element.setAttribute!("id", "swui-atomic")
        _ = document.head.appendChild(element)
        return element
    }

    public static func apply(
        _ batch: BrowserDOMCommandBatch,
        hydrationIndex: BrowserHydrationIndex
    ) {
        for command in batch.commands {
            apply(command, hydrationIndex: hydrationIndex)
        }
    }

    // Monotonic token so only the most recent withAnimation's cleanup tears down the
    // document scope. Without it, an earlier event's timer would strip the scope a
    // later, still-running withAnimation depends on. Single-threaded (WASI), but
    // Mutex keeps it Sendable-correct.
    private static let animationScopeGeneration = Mutex(0)

    /// Applies a batch whose changes an explicit `withAnimation` transaction asked
    /// to be interpolated. The whole document is made an animation scope for the
    /// transaction's timing so the existing
    /// `.swui-animation-scope * { transition: … var(--swui-animation, 0s) }` rule
    /// animates every change this batch makes; the scope is removed once the
    /// animation finishes so later, non-animated updates are not interpolated.
    public static func apply(
        _ batch: BrowserDOMCommandBatch,
        hydrationIndex: BrowserHydrationIndex,
        animation: TransactionAnimation?
    ) {
        guard let animation else {
            apply(batch, hydrationIndex: hydrationIndex)
            return
        }
        let body: JSValue = document.body
        let generation = animationScopeGeneration.withLock { value -> Int in
            value += 1
            return value
        }
        _ = body.classList.add("swui-animation-scope")
        animationStyleElement().textContent = .string(".swui-animation-scope { --swui-animation: \(animation.css) }")
        // Commit the scope's transition (with the pre-patch values) before mutating,
        // so the upcoming property changes start from a state where the transition is
        // already active and therefore animate.
        _ = body.offsetHeight.number
        apply(batch, hydrationIndex: hydrationIndex)
        let cleanup = JSOneshotClosure { _ in
            // Only the latest withAnimation owns the scope; an earlier timer must not
            // tear down a scope a later one is still using.
            let isLatest = animationScopeGeneration.withLock { $0 == generation }
            if isLatest {
                _ = body.classList.remove("swui-animation-scope")
                animationStyleElement().textContent = .string("")
            }
            return .undefined
        }
        _ = JSObject.global.setTimeout!(cleanup, motionAdjustedDelay(Double(animation.durationMilliseconds)))
    }

    private static func animationStyleElement() -> JSObject {
        if let element = document.getElementById("swui-animation").object {
            return element
        }
        let element = document.createElement("style").object!
        // JSObject dynamic methods are optional callables in the JavaScriptKit fork.
        _ = element.setAttribute!("id", "swui-animation")
        _ = document.head.appendChild(element)
        return element
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
        if let record = hydrationIndex.node(nodeID) {
            switch record.role {
            case .component, .serverSlot, .fragment, .document:
                if replaceRenderedRange(record, html: html, hydrationIndex: hydrationIndex) {
                    return
                }
                reportUnresolvedTarget(nodeID, operation: "replaceSubtree")
                return
            case .rawHTML:
                replaceRawHTMLContents(record, html: html, hydrationIndex: hydrationIndex)
                return
            default:
                break
            }
        }
        // A rawHTML node carries no hydration node marker and may expand to any
        // number of DOM nodes, so it cannot be selected or replaced directly.
        // Resolve it through its parent: when the rawHTML is the sole child of an
        // addressable element, replacing the parent's contents is the unambiguous,
        // context-correct patch (e.g. a <style> whose CSS changes after an environment update).
        guard let node = resolveDOMNode(nodeID, hydrationIndex: hydrationIndex) else {
            reportUnresolvedTarget(nodeID, operation: "replaceSubtree")
            return
        }
        let range = document.createRange()
        _ = range.selectNode(node)
        let fragment = range.createContextualFragment(html)
        _ = node.replaceWith(fragment)
    }

    private static func replaceRenderedRange(
        _ record: BrowserHydrationNodeRecord,
        html: String,
        hydrationIndex: BrowserHydrationIndex
    ) -> Bool {
        guard let boundary = renderedBoundary(for: record, hydrationIndex: hydrationIndex) else {
            return false
        }
        let range = document.createRange()
        _ = range.setStartBefore(boundary.first)
        _ = range.setEndAfter(boundary.last)
        let fragment = range.createContextualFragment(html)
        _ = range.deleteContents()
        _ = range.insertNode(fragment)
        return true
    }

    private static func renderedBoundary(
        for record: BrowserHydrationNodeRecord,
        hydrationIndex: BrowserHydrationIndex
    ) -> (first: JSValue, last: JSValue)? {
        switch record.role {
        case .component, .serverSlot:
            return boundaryComments(for: record)
        case .fragment, .document:
            guard let firstChild = record.childIDs.first,
                  let lastChild = record.childIDs.last,
                  let firstRecord = hydrationIndex.node(firstChild),
                  let lastRecord = hydrationIndex.node(lastChild),
                  let first = renderedBoundary(for: firstRecord, hydrationIndex: hydrationIndex)?.first
                    ?? resolveDOMNode(firstChild, hydrationIndex: hydrationIndex),
                  let last = renderedBoundary(for: lastRecord, hydrationIndex: hydrationIndex)?.last
                    ?? resolveDOMNode(lastChild, hydrationIndex: hydrationIndex)
            else {
                return nil
            }
            return (first, last)
        default:
            guard let node = resolveDOMNode(record.id, hydrationIndex: hydrationIndex) else {
                return nil
            }
            return (node, node)
        }
    }

    private static func boundaryComments(
        for record: BrowserHydrationNodeRecord
    ) -> (first: JSValue, last: JSValue)? {
        let prefix: String
        switch record.role {
        case .component:
            guard let componentID = record.componentID else {
                return nil
            }
            prefix = "\(HTMLRuntimeMarkers.componentCommentPrefix):\(componentID.rawValue)"
        case .serverSlot:
            guard let serverSlotID = record.serverSlotID else {
                return nil
            }
            prefix = "\(HTMLRuntimeMarkers.serverSlotCommentPrefix):\(serverSlotID.rawValue)"
        default:
            return nil
        }

        let walker = document.createTreeWalker(document, 128)
        var begin: JSValue?
        while true {
            let node = walker.nextNode()
            if node.isNull || node.isUndefined {
                break
            }
            guard let value = node.nodeValue.string else {
                continue
            }
            if value == "\(prefix):begin" {
                begin = node
            } else if value == "\(prefix):end", let begin {
                return (begin, node)
            }
        }
        return nil
    }

    private static func replaceRawHTMLContents(
        _ record: BrowserHydrationNodeRecord,
        html: String,
        hydrationIndex: BrowserHydrationIndex
    ) {
        guard let parentID = record.parentID,
              let parentRecord = hydrationIndex.node(parentID),
              parentRecord.childIDs == [record.id],
              let parent = resolveDOMNode(parentID, hydrationIndex: hydrationIndex)
        else {
            // A rawHTML node that shares its parent with siblings, or whose parent
            // is not an addressable element, cannot be patched in place. Surface it
            // instead of silently dropping the update.
            reportUnresolvedRawHTML(record)
            return
        }
        // Parse the replacement in the parent's content context so raw-text parents
        // (<style>/<script>) keep their CSS/JS verbatim while normal parents parse
        // the markup as HTML.
        let range = document.createRange()
        _ = range.selectNodeContents(parent)
        _ = range.deleteContents()
        let fragment = range.createContextualFragment(html)
        _ = parent.appendChild(fragment)
    }

    private static func updateText(
        _ nodeID: HTMLNodeID,
        value: String,
        hydrationIndex: BrowserHydrationIndex
    ) {
        guard let node = resolveDOMNode(nodeID, hydrationIndex: hydrationIndex) else {
            reportUnresolvedTarget(nodeID, operation: "updateText")
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
            reportUnresolvedTarget(nodeID, operation: "updateAttributes")
            return
        }
        let nodeValue = JSValue.object(object)

        let internalNode = nodeValue.getAttribute(HTMLRuntimeMarkers.nodeAttribute).string
        let internalKey = nodeValue.getAttribute(HTMLRuntimeMarkers.keyAttribute).string
        let names = Set(attributes.map(\.name))
        let existing = object.attributes
        let count = Int(existing.length.number ?? 0)
        var removable: [String] = []
        for index in 0..<count {
            let attribute = existing[index]
            guard let name = attribute.name.string,
                  name != HTMLRuntimeMarkers.nodeAttribute,
                  name != HTMLRuntimeMarkers.keyAttribute,
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
            _ = nodeValue.setAttribute(HTMLRuntimeMarkers.nodeAttribute, internalNode)
        }
        if let internalKey {
            _ = nodeValue.setAttribute(HTMLRuntimeMarkers.keyAttribute, internalKey)
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
            reportUnresolvedTarget(nodeID, operation: "setProperty")
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
        guard let context = mutationContext(parent: parentID, index: index, hydrationIndex: hydrationIndex),
              let node = resolveDOMNode(nodeID, hydrationIndex: hydrationIndex)
        else {
            reportUnresolvedTarget(nodeID, operation: "insertNode")
            return
        }
        _ = context.parent.insertBefore(node, context.reference ?? .null)
    }

    private static func insertHTML(
        parent parentID: HTMLNodeID,
        index: Int,
        html: String,
        hydrationIndex: BrowserHydrationIndex
    ) {
        guard let context = mutationContext(parent: parentID, index: index, hydrationIndex: hydrationIndex) else {
            reportUnresolvedTarget(parentID, operation: "insertHTML")
            return
        }
        let range = document.createRange()
        let fragment = range.createContextualFragment(html)
        _ = context.parent.insertBefore(fragment, context.reference ?? .null)
    }

    private static func removeNode(
        parent parentID: HTMLNodeID,
        index: Int,
        node nodeID: HTMLNodeID,
        hydrationIndex: BrowserHydrationIndex
    ) {
        // A node carrying an exit transition animates out first, then detaches.
        // This MUST run before the rendered-range fast path below, which would
        // otherwise delete the node instantly and skip the animation. Only element
        // nodes (nodeType 1) carry the markers; the exact node is detached directly
        // (not by index) so a concurrent re-insert of the same slot is unaffected.
        if let node = resolveDOMNode(nodeID, hydrationIndex: hydrationIndex),
           node.nodeType.number == 1,
           node.getAttribute("data-swui-transition").string == "1",
           let milliseconds = node.getAttribute("data-swui-exit-ms").string.flatMap(Double.init),
           milliseconds > 0 {
            _ = node.classList.add("swui-exiting")
            let removal = JSOneshotClosure { _ in
                if let parent = resolvedNode(node.parentNode) {
                    _ = parent.removeChild(node)
                }
                return .undefined
            }
            _ = JSObject.global.setTimeout!(removal, motionAdjustedDelay(milliseconds))
            return
        }
        if let record = hydrationIndex.node(nodeID),
           removeRenderedNode(record, hydrationIndex: hydrationIndex) {
            return
        }
        guard let context = mutationContext(parent: parentID, index: index, hydrationIndex: hydrationIndex) else {
            reportUnresolvedTarget(parentID, operation: "removeNode")
            return
        }
        let node = resolveDOMNode(nodeID, hydrationIndex: hydrationIndex)
            ?? childNode(parent: context.parent, index: index)
        guard let node else {
            reportUnresolvedTarget(nodeID, operation: "removeNode")
            return
        }
        _ = context.parent.removeChild(node)
    }

    /// Zero when the user prefers reduced motion (so animated detaches/cleanups
    /// happen promptly, matching the near-instant CSS), otherwise `milliseconds`.
    private static func motionAdjustedDelay(_ milliseconds: Double) -> Double {
        prefersReducedMotion() ? 0 : milliseconds
    }

    private static func prefersReducedMotion() -> Bool {
        guard let query = JSObject.global.matchMedia?("(prefers-reduced-motion: reduce)") else {
            return false
        }
        return query.matches.boolean ?? false
    }

    private static func moveNode(
        parent parentID: HTMLNodeID,
        from sourceIndex: Int,
        to destinationIndex: Int,
        hydrationIndex: BrowserHydrationIndex
    ) {
        if let parentRecord = hydrationIndex.node(parentID),
           parentRecord.childIDs.indices.contains(sourceIndex),
           let childRecord = hydrationIndex.node(parentRecord.childIDs[sourceIndex]),
           moveRenderedNode(
            parentRecord: parentRecord,
            record: childRecord,
            destinationIndex: destinationIndex,
            hydrationIndex: hydrationIndex
           ) {
            return
        }
        guard let context = mutationContext(parent: parentID, index: sourceIndex, hydrationIndex: hydrationIndex),
              let node = childNode(parent: context.parent, index: sourceIndex)
        else {
            reportUnresolvedTarget(parentID, operation: "moveNode")
            return
        }
        let destination = mutationContext(parent: parentID, index: destinationIndex, hydrationIndex: hydrationIndex)
        _ = context.parent.insertBefore(node, destination?.reference ?? .null)
    }

    private static func moveKeyedNode(
        parent parentID: HTMLNodeID,
        key: Key,
        to destinationIndex: Int,
        hydrationIndex: BrowserHydrationIndex
    ) {
        let identity = domKeyIdentity(for: key)
        if let parentRecord = hydrationIndex.node(parentID),
           let childRecord = parentRecord.childIDs
            .compactMap({ hydrationIndex.node($0) })
            .first(where: { record in
                guard let key = record.key else {
                    return false
                }
                return domKeyIdentity(for: key) == identity
            }),
           moveRenderedNode(
            parentRecord: parentRecord,
            record: childRecord,
            destinationIndex: destinationIndex,
            hydrationIndex: hydrationIndex
           ) {
            return
        }
        guard let context = mutationContext(parent: parentID, index: destinationIndex, hydrationIndex: hydrationIndex) else {
            reportUnresolvedTarget(parentID, operation: "moveKeyedNode")
            return
        }
        let node = document.querySelector("[\(HTMLRuntimeMarkers.keyAttribute)=\"\(cssEscape(identity))\"]")
        if node.isNull || node.isUndefined {
            reportUnresolvedTarget(parentID, operation: "moveKeyedNode(key)")
            return
        }
        _ = context.parent.insertBefore(node, context.reference ?? .null)
    }

    private static func mutationContext(
        parent parentID: HTMLNodeID,
        index: Int,
        hydrationIndex: BrowserHydrationIndex
    ) -> (parent: JSValue, reference: JSValue?)? {
        guard let record = hydrationIndex.node(parentID) else {
            guard let parent = resolveDOMNode(parentID, hydrationIndex: hydrationIndex) else {
                return nil
            }
            return (parent, childNode(parent: parent, index: index))
        }

        switch record.role {
        case .element:
            guard let parent = resolveDOMNode(record.id, hydrationIndex: hydrationIndex) else {
                return nil
            }
            return (
                parent,
                referenceNode(forLogicalIndex: index, in: record, hydrationIndex: hydrationIndex)
            )
        case .component, .serverSlot:
            guard let boundary = boundaryComments(for: record),
                  let parent = resolvedNode(boundary.first.parentNode)
            else {
                return nil
            }
            return (
                parent,
                referenceNode(forLogicalIndex: index, in: record, hydrationIndex: hydrationIndex) ?? boundary.last
            )
        case .fragment, .document:
            if let boundary = renderedBoundary(for: record, hydrationIndex: hydrationIndex),
               let parent = resolvedNode(boundary.first.parentNode) {
                return (
                    parent,
                    referenceNode(forLogicalIndex: index, in: record, hydrationIndex: hydrationIndex)
                        ?? resolvedNode(boundary.last.nextSibling)
                )
            }
            return transparentContainerContext(record, hydrationIndex: hydrationIndex)
        default:
            guard let parent = resolveDOMNode(record.id, hydrationIndex: hydrationIndex) else {
                return nil
            }
            return (parent, childNode(parent: parent, index: index))
        }
    }

    private static func referenceNode(
        forLogicalIndex index: Int,
        in record: BrowserHydrationNodeRecord,
        hydrationIndex: BrowserHydrationIndex
    ) -> JSValue? {
        for childID in record.childIDs.dropFirst(Swift.max(0, index)) {
            guard let childRecord = hydrationIndex.node(childID) else {
                continue
            }
            if let boundary = renderedBoundary(for: childRecord, hydrationIndex: hydrationIndex),
               resolvedNode(boundary.first.parentNode) != nil {
                return boundary.first
            }
            if let node = resolveDOMNode(childID, hydrationIndex: hydrationIndex),
               resolvedNode(node.parentNode) != nil {
                return node
            }
        }
        return nil
    }

    private static func transparentContainerContext(
        _ record: BrowserHydrationNodeRecord,
        hydrationIndex: BrowserHydrationIndex
    ) -> (parent: JSValue, reference: JSValue?)? {
        if record.role == .document {
            let body: JSValue = document.body
            if !body.isNull && !body.isUndefined {
                return (body, nil)
            }
            let documentElement: JSValue = document.documentElement
            guard let resolvedElement = resolvedNode(documentElement) else {
                return nil
            }
            return (resolvedElement, nil)
        }
        guard let parentID = record.parentID,
              let parentRecord = hydrationIndex.node(parentID),
              let index = parentRecord.childIDs.firstIndex(of: record.id)
        else {
            return nil
        }
        return mutationContext(parent: parentID, index: index + 1, hydrationIndex: hydrationIndex)
    }

    private static func removeRenderedNode(
        _ record: BrowserHydrationNodeRecord,
        hydrationIndex: BrowserHydrationIndex
    ) -> Bool {
        if let boundary = renderedBoundary(for: record, hydrationIndex: hydrationIndex) {
            let range = document.createRange()
            _ = range.setStartBefore(boundary.first)
            _ = range.setEndAfter(boundary.last)
            _ = range.deleteContents()
            return true
        }
        guard let node = resolveDOMNode(record.id, hydrationIndex: hydrationIndex),
              let parent = resolvedNode(node.parentNode)
        else {
            return false
        }
        _ = parent.removeChild(node)
        return true
    }

    private static func moveRenderedNode(
        parentRecord: BrowserHydrationNodeRecord,
        record: BrowserHydrationNodeRecord,
        destinationIndex: Int,
        hydrationIndex: BrowserHydrationIndex
    ) -> Bool {
        guard let boundary = renderedBoundary(for: record, hydrationIndex: hydrationIndex),
              let context = mutationContext(
                parent: parentRecord.id,
                index: destinationIndex,
                hydrationIndex: hydrationIndex
              )
        else {
            return false
        }
        if let reference = context.reference,
           renderedRange(boundary, contains: reference) {
            return true
        }
        let range = document.createRange()
        _ = range.setStartBefore(boundary.first)
        _ = range.setEndAfter(boundary.last)
        let fragment = range.extractContents()
        _ = context.parent.insertBefore(fragment, context.reference ?? .null)
        return true
    }

    private static func renderedRange(
        _ boundary: (first: JSValue, last: JSValue),
        contains target: JSValue
    ) -> Bool {
        var current: JSValue? = boundary.first
        while let node = current, !node.isNull, !node.isUndefined {
            if node.isSameNode(target).boolean == true {
                return true
            }
            if node.isSameNode(boundary.last).boolean == true {
                return false
            }
            let next: JSValue = node.nextSibling
            current = next.isNull || next.isUndefined ? nil : next
        }
        return false
    }

    private static func domKeyIdentity(for key: Key) -> String {
        do {
            let data = try JSONEncoder().encode(key)
            let payload = try JSONDecoder().decode(DOMKeyIdentityPayload.self, from: data)
            return payload.identity ?? payload.rawValue
        } catch {
            // The key should always round-trip; a failure means a keyed move may
            // target the wrong element. Surface it instead of silently falling
            // back, then use the rawValue as the best available identity.
            _ = JSObject.global.console.error(
                "[SwiftWebUI] domKeyIdentity: could not decode key identity (\(error)); using rawValue \"\(key.rawValue)\"."
            )
            return key.rawValue
        }
    }

    private static func childNode(parent: JSValue, index: Int) -> JSValue? {
        let value = parent.childNodes[index]
        return value.isNull || value.isUndefined ? nil : value
    }

    private static func resolvedNode(_ value: JSValue) -> JSValue? {
        value.isNull || value.isUndefined ? nil : value
    }

    private static func resolveDOMNode(
        _ nodeID: HTMLNodeID,
        hydrationIndex: BrowserHydrationIndex
    ) -> JSValue? {
        let direct = document.querySelector("[\(HTMLRuntimeMarkers.nodeAttribute)=\"\(nodeID.rawValue)\"]")
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

    private static func reportUnresolvedTarget(_ nodeID: HTMLNodeID, operation: String) {
        _ = JSObject.global.console.error(
            "[SwiftWebUI] \(operation): could not resolve DOM node \(nodeID.rawValue); patch dropped."
        )
    }

    private static func reportUnresolvedRawHTML(_ record: BrowserHydrationNodeRecord) {
        _ = JSObject.global.console.error(
            "[SwiftWebUI] replaceSubtree: rawHTML node \(record.id.rawValue) is not addressable "
                + "(it must be the sole child of an addressable element); patch dropped."
        )
    }

    private static func cssEscape(_ value: String) -> String {
        value
            .replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "\"", with: "\\\"")
    }
}

private struct DOMKeyIdentityPayload: Decodable {
    let rawValue: String
    let identity: String?
}
#endif
