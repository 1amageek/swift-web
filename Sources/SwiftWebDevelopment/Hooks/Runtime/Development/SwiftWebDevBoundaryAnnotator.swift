import Foundation
import SwiftHTML

enum SwiftWebDevBoundaryAnnotator {
    static func annotate(
        _ html: String,
        manifest: ClientBundleManifest,
        hydrationIndex: BrowserHydrationIndex,
        isEnabled: Bool = SwiftWebDevHotReload.isEnabled
    ) -> String {
        guard isEnabled else {
            return html
        }

        var output = html

        for component in boundaryComponents(manifest: manifest, hydrationIndex: hydrationIndex) {
            annotate(component, in: &output)
        }

        return output
    }

    private static func boundaryComponents(
        manifest: ClientBundleManifest,
        hydrationIndex: BrowserHydrationIndex
    ) -> [ClientComponentAsset] {
        let manifestComponentsByID = Dictionary(
            uniqueKeysWithValues: manifest.components.map { ($0.componentID, $0) }
        )
        let hydrationComponentsByID = Dictionary(
            uniqueKeysWithValues: hydrationIndex.components.map { ($0.id, $0) }
        )
        let componentIDsByNodeID = Dictionary(
            uniqueKeysWithValues: hydrationIndex.components.map { ($0.nodeID, $0.id) }
        )
        let nodesByID = Dictionary(
            uniqueKeysWithValues: hydrationIndex.nodes.map { ($0.id, $0) }
        )

        let candidates = manifest.components.filter { component in
            guard let hydrationComponent = hydrationComponentsByID[component.componentID] else {
                return false
            }
            return isBoundaryComponent(
                component,
                hydrationComponent: hydrationComponent,
                manifestComponentsByID: manifestComponentsByID,
                componentIDsByNodeID: componentIDsByNodeID,
                nodesByID: nodesByID
            )
        }
        return candidates.sorted { left, right in
            let leftPath = hydrationComponentsByID[left.componentID]?.path ?? ""
            let rightPath = hydrationComponentsByID[right.componentID]?.path ?? ""
            let leftDepth = leftPath.split(separator: "/").count
            let rightDepth = rightPath.split(separator: "/").count
            if leftDepth != rightDepth {
                return leftDepth < rightDepth
            }
            if left.bundleID != right.bundleID {
                if left.bundleID == manifest.runtimeBundleID {
                    return false
                }
                if right.bundleID == manifest.runtimeBundleID {
                    return true
                }
            }
            return left.componentID.rawValue < right.componentID.rawValue
        }
    }

    private static func isBoundaryComponent(
        _ component: ClientComponentAsset,
        hydrationComponent: BrowserHydrationComponentRecord,
        manifestComponentsByID: [ComponentID: ClientComponentAsset],
        componentIDsByNodeID: [HTMLNodeID: ComponentID],
        nodesByID: [HTMLNodeID: BrowserHydrationNodeRecord]
    ) -> Bool {
        var currentID = nodesByID[hydrationComponent.nodeID]?.parentID
        while let nodeID = currentID {
            if let ancestorComponentID = componentIDsByNodeID[nodeID],
               let ancestor = manifestComponentsByID[ancestorComponentID] {
                return ancestor.bundleID != component.bundleID
            }
            currentID = nodesByID[nodeID]?.parentID
        }
        return true
    }

    private static func annotate(_ component: ClientComponentAsset, in html: inout String) {
        let marker = HTMLRuntimeMarkers.comment(
            prefix: HTMLRuntimeMarkers.componentCommentPrefix,
            id: component.componentID.rawValue,
            edge: .begin
        )
        guard let markerRange = html.range(of: marker),
              let tagRange = firstElementTagRange(in: html, after: markerRange.upperBound)
        else {
            return
        }

        let tag = String(html[tagRange])
        guard !tag.contains("data-hmr-boundary=") else {
            return
        }

        let cleanedTag = removingAttributes(
            [
                "data-component",
                "data-hmr-boundary",
                "data-state-schema",
                "data-environment-schema",
                "data-component-type",
                "data-bundle",
            ],
            from: tag
        )
        let attributes = [
            ("data-component", component.componentID.rawValue),
            ("data-hmr-boundary", "true"),
            ("data-state-schema", component.stateSchemaHash),
            ("data-environment-schema", component.environmentSchemaHash),
            ("data-component-type", component.typeName),
            ("data-bundle", component.bundleID.rawValue),
        ]
        .map { name, value in
            "\(name)=\"\(escapeAttribute(value))\""
        }
        .joined(separator: " ")

        html.replaceSubrange(tagRange, with: "\(cleanedTag) \(attributes)")
    }

    private static func firstElementTagRange(
        in html: String,
        after start: String.Index
    ) -> Range<String.Index>? {
        var index = start
        while let lessThan = html[index...].firstIndex(of: "<") {
            if html[lessThan...].hasPrefix("<!--") {
                guard let commentEnd = html[lessThan...].range(of: "-->") else {
                    return nil
                }
                index = commentEnd.upperBound
                continue
            }

            let next = html.index(after: lessThan)
            guard next < html.endIndex else {
                return nil
            }
            let nextCharacter = html[next]
            if nextCharacter == "/" || nextCharacter == "!" || nextCharacter == "?" {
                index = next
                continue
            }

            guard let greaterThan = closingAngleBracket(in: html, from: next) else {
                return nil
            }
            return next..<greaterThan
        }
        return nil
    }

    private static func closingAngleBracket(
        in html: String,
        from start: String.Index
    ) -> String.Index? {
        var index = start
        var quote: Character?
        while index < html.endIndex {
            let character = html[index]
            if let currentQuote = quote {
                if character == currentQuote {
                    quote = nil
                }
            } else if character == "\"" || character == "'" {
                quote = character
            } else if character == ">" {
                return index
            }
            index = html.index(after: index)
        }
        return nil
    }

    private static func escapeAttribute(_ value: String) -> String {
        var output = ""
        output.reserveCapacity(value.count)
        for character in value {
            switch character {
            case "&":
                output += "&amp;"
            case "\"":
                output += "&quot;"
            case "<":
                output += "&lt;"
            case ">":
                output += "&gt;"
            default:
                output.append(character)
            }
        }
        return output
    }

    private static func removingAttributes(_ names: [String], from tag: String) -> String {
        var output = tag
        for name in names {
            do {
                let escapedName = NSRegularExpression.escapedPattern(for: name)
                let pattern = #"\s+"# + escapedName + #"(?:\s*=\s*(?:"[^"]*"|'[^']*'|[^\s"'>/=`]+))?"#
                let expression = try NSRegularExpression(pattern: pattern)
                output = expression.stringByReplacingMatches(
                    in: output,
                    range: NSRange(output.startIndex..<output.endIndex, in: output),
                    withTemplate: ""
                )
            } catch {
                assertionFailure("Failed to compile SwiftWeb dev boundary attribute expression: \(error)")
            }
        }
        return output
    }
}
