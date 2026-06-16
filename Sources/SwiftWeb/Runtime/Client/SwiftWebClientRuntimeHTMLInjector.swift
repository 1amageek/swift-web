import Foundation
import SwiftHTML

struct SwiftWebClientRuntimeHTMLInjector {
    static let descriptorElementID = "swift-web-client-runtime"

    private let encoder: JSONEncoder

    init(encoder: JSONEncoder = JSONEncoder()) {
        self.encoder = encoder
    }

    func inject(
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
        if let headEndRange = html.range(of: "</head>", options: [.caseInsensitive, .backwards]) {
            var output = html
            output.insert(contentsOf: markup, at: headEndRange.lowerBound)
            return output
        }
        return markup + html
    }

    private func injectBodyMarkup(_ markup: String, into html: String) -> String {
        if let bodyEndRange = html.range(of: "</body>", options: [.caseInsensitive, .backwards]) {
            var output = html
            output.insert(contentsOf: markup, at: bodyEndRange.lowerBound)
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
