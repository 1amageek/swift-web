import Foundation
import SwiftHTML

struct SwiftWebDevEvent: Sendable, Codable, Equatable {
    let id: String
    let kind: Kind
    let message: String?
    let stylePatch: SwiftWebDevStylePatch?
    let clientComponentUpdate: ClientWasmHMRManifest?
    let changedPaths: [String]

    init(
        id: String = SwiftWebDevEventID.next(),
        kind: Kind,
        message: String? = nil,
        stylePatch: SwiftWebDevStylePatch? = nil,
        clientComponentUpdate: ClientWasmHMRManifest? = nil,
        changedPaths: [String] = []
    ) {
        self.id = id
        self.kind = kind
        self.message = message
        self.stylePatch = stylePatch
        self.clientComponentUpdate = clientComponentUpdate
        self.changedPaths = changedPaths
    }

    enum Kind: String, Sendable, Codable {
        case connected
        case stylePatch
        case clientComponentUpdate
        case serverBuildStarted
        case serverRestarted
        case pagePatch
        case fullReload
        case error
    }
}

struct SwiftWebDevStylePatch: Sendable, Codable, Equatable {
    let id: String
    let css: String

    init(id: String = "swift-web-dev-style-hmr", css: String) {
        self.id = id
        self.css = css
    }
}

struct ClientWasmHMRManifest: Sendable, Codable, Equatable {
    let componentTypeName: String
    let bundleID: ClientBundleID
    let assetPath: String
    let contentHash: String
    let stateSchemaHash: String
    let environmentSchemaHash: String

    init(
        componentTypeName: String,
        bundleID: ClientBundleID,
        assetPath: String,
        contentHash: String,
        stateSchemaHash: String,
        environmentSchemaHash: String
    ) {
        self.componentTypeName = componentTypeName
        self.bundleID = bundleID
        self.assetPath = assetPath
        self.contentHash = contentHash
        self.stateSchemaHash = stateSchemaHash
        self.environmentSchemaHash = environmentSchemaHash
    }
}

enum SwiftWebDevEventID {
    static func next() -> String {
        "\(Int(Date().timeIntervalSince1970 * 1_000_000))-\(UUID().uuidString)"
    }
}
