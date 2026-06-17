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

        return manifest.components.filter { component in
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
        let marker = "<!--swift-html-component:\(component.componentID.rawValue):begin-->"
        guard let markerRange = html.range(of: marker),
              let tagRange = firstElementTagRange(in: html, after: markerRange.upperBound)
        else {
            return
        }

        let tag = html[tagRange]
        guard !tag.contains("data-swift-hmr-boundary=") else {
            return
        }

        let attributes = [
            ("data-swift-component", component.componentID.rawValue),
            ("data-swift-hmr-boundary", "true"),
            ("data-swift-state-schema", component.stateSchemaHash),
            ("data-swift-environment-schema", component.environmentSchemaHash),
            ("data-swift-component-type", component.typeName),
            ("data-swift-bundle", component.bundleID.rawValue),
        ]
        .map { name, value in
            "\(name)=\"\(escapeAttribute(value))\""
        }
        .joined(separator: " ")

        html.insert(contentsOf: " \(attributes)", at: tagRange.upperBound)
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
}
