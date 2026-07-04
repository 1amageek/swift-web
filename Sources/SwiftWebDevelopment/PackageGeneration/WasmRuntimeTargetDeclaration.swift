import SwiftHTML
import SwiftWebDevelopmentHooks
import SwiftWebWasmBuild

struct WasmRuntimeTargetDeclaration: Sendable {
  let targetName: String
  let bundleID: ClientBundleID
  let componentTypeNames: [String]
  var actorContracts: [ClientActorContractDeclaration] = []
  var bundleArtifacts: [WasmRuntimeBundleArtifactDeclaration] = []
  let linkMode: SwiftWebGeneratedWasmRuntimeLinkMode

  var componentTypeName: String {
    componentTypeNames.first ?? targetName
  }
}
