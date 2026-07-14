#if !hasFeature(Embedded)
#if canImport(FoundationEssentials)
import FoundationEssentials
#elseif canImport(Foundation)
import Foundation
#endif
import SwiftHTML

package struct SwiftWebClientRuntimeHTMLInjector {
    package static let descriptorElementID = "client-runtime"

    private let encoder: JSONEncoder

    package init(encoder: JSONEncoder = JSONEncoder()) {
        self.encoder = encoder
    }

    package func inject(
        into html: String,
        descriptor: SwiftWebClientRuntimeDescriptor,
        nonce: String? = nil
    ) throws -> String {
        var output = html
        if let wasm = descriptor.wasm {
            output = injectHeadMarkup(
                wasmPreloadMarkup(for: wasm, hasInlineManifest: descriptor.manifest != nil),
                into: output
            )
        }
        output = try injectBodyMarkup(bodyMarkup(for: descriptor, nonce: nonce), into: output)
        return output
    }

    private func bodyMarkup(for descriptor: SwiftWebClientRuntimeDescriptor, nonce: String?) throws -> String {
        let descriptorJSON = try descriptorJSON(for: descriptor)
        let nonceAttribute = nonce.map { " nonce=\"\(HTMLWriter.escapeAttribute($0))\"" } ?? ""
        var markup = """
        <script type="application/json" id="\(Self.descriptorElementID)"\(nonceAttribute)>\(descriptorJSON)</script>
        """
        if let wasm = descriptor.wasm {
            markup += """
            <script type="module" src="\(HTMLWriter.escapeAttribute(wasm.hostScriptPath))"\(nonceAttribute)></script>
            """
        }
        return markup
    }

    private func wasmPreloadMarkup(
        for runtime: SwiftWebWasmClientRuntime,
        hasInlineManifest: Bool
    ) -> String {
        var markup = """
        <link rel="preload" href="\(HTMLWriter.escapeAttribute(runtime.runtimeAssetPath))" as="fetch" type="application/wasm" crossorigin="anonymous">
        """
        if !hasInlineManifest {
            markup += """
            <link rel="preload" href="\(HTMLWriter.escapeAttribute(runtime.manifestPath))" as="fetch" type="application/json" crossorigin="anonymous">
            """
        }
        return markup
    }

    private func injectHeadMarkup(_ markup: String, into html: String) -> String {
        // Last case-insensitive occurrence, without Foundation's
        // range(of:options:): search the lowercased copy and map the offset back.
        let lowered = html.lowercased()
        if let range = lowered.ranges(of: "</head>").last {
            var output = html
            let offset = lowered.distance(from: lowered.startIndex, to: range.lowerBound)
            output.insert(contentsOf: markup, at: output.index(output.startIndex, offsetBy: offset))
            return output
        }
        return markup + html
    }

    private func injectBodyMarkup(_ markup: String, into html: String) -> String {
        // Last case-insensitive occurrence, without Foundation's
        // range(of:options:): search the lowercased copy and map the offset back.
        let lowered = html.lowercased()
        if let range = lowered.ranges(of: "</body>").last {
            var output = html
            let offset = lowered.distance(from: lowered.startIndex, to: range.lowerBound)
            output.insert(contentsOf: markup, at: output.index(output.startIndex, offsetBy: offset))
            return output
        }
        return html + markup
    }

    private func descriptorJSON(for descriptor: SwiftWebClientRuntimeDescriptor) throws -> String {
        let data = try encoder.encode(descriptor)
        return String(decoding: data, as: UTF8.self)
            .replacingOccurrences(of: "<", with: "\\u003C")
            .replacingOccurrences(of: ">", with: "\\u003E")
            .replacingOccurrences(of: "&", with: "\\u0026")
    }
}
#endif
