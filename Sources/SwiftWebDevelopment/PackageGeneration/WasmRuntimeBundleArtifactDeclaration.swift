import SwiftHTML
import SwiftWebDevelopmentHooks

struct WasmRuntimeBundleArtifactDeclaration: Sendable {
  let bundleID: ClientBundleID
  let componentTypeNames: [String]
}
