import Foundation
import SwiftHTML

package struct SwiftWebDevEvent: Sendable, Codable, Equatable {
  package let id: String
  package let kind: Kind
  package let message: String?
  package let stylePatch: SwiftWebDevStylePatch?
  package let clientComponentUpdate: ClientRuntimeHMRManifest?
  package let changedPaths: [String]

  package init(
    id: String = SwiftWebDevEventID.next(),
    kind: Kind,
    message: String? = nil,
    stylePatch: SwiftWebDevStylePatch? = nil,
    clientComponentUpdate: ClientRuntimeHMRManifest? = nil,
    changedPaths: [String] = []
  ) {
    self.id = id
    self.kind = kind
    self.message = message
    self.stylePatch = stylePatch
    self.clientComponentUpdate = clientComponentUpdate
    self.changedPaths = changedPaths
  }

  package enum Kind: String, Sendable, Codable {
    case connected
    case stylePatch
    case clientBuildStarted
    case clientComponentUpdate
    case serverBuildStarted
    case serverRestarted
    case pagePatch
    case fullReload
    case error
  }
}

package struct SwiftWebDevStylePatch: Sendable, Codable, Equatable {
  package let id: String
  package let css: String

  package init(id: String = "dev-style-hmr", css: String) {
    self.id = id
    self.css = css
  }
}

package struct ClientRuntimeHMRManifest: Sendable, Codable, Equatable {
  package let componentTypeName: String
  package let bundleID: ClientBundleID
  package let assetPath: String
  package let contentHash: String
  package let stateSchemaHash: String
  package let environmentSchemaHash: String

  package init(
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

package enum SwiftWebDevEventID {
  package static func next() -> String {
    "\(Int(Date().timeIntervalSince1970 * 1_000_000))-\(UUID().uuidString)"
  }
}
