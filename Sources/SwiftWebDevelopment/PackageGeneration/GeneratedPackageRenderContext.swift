import Foundation
import SwiftWebWasmBuild

struct GeneratedPackageRenderContext: Sendable {
  let layout: GeneratedPackageLayout
  let swiftWebPackageDirectory: URL
  let appPackageName: String
  let appPackageDependencyName: String
  let appProductName: String
  let serverProductName: String
  let developmentServerProductName: String
  let devProductName: String
  let wasmRuntimeTargets: [WasmRuntimeTargetDeclaration]
  let clientEnvironmentKeyTypeNames: [String]
  let actorRuntimeDependencyDeclaration: String
  let wasmRuntimeProfile: SwiftWebWasmRuntimeProfile
}
