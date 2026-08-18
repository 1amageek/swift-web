import Foundation
import SwiftWebWasmBuild

struct GeneratedActorDependencyTarget: Sendable {
  let moduleName: String
  let dependencyModuleNames: [String]
  let clientImportedModuleNames: [String]
  let customConditions: Set<String>
  let upcomingFeatures: Set<String>
  let experimentalFeatures: Set<String>
  let bootstrapTypeName: String?

  init(
    moduleName: String,
    dependencyModuleNames: [String],
    clientImportedModuleNames: [String] = [],
    customConditions: Set<String> = [],
    upcomingFeatures: Set<String> = [],
    experimentalFeatures: Set<String> = [],
    bootstrapTypeName: String?
  ) {
    self.moduleName = moduleName
    self.dependencyModuleNames = dependencyModuleNames
    self.clientImportedModuleNames = clientImportedModuleNames
    self.customConditions = customConditions
    self.upcomingFeatures = upcomingFeatures
    self.experimentalFeatures = experimentalFeatures
    self.bootstrapTypeName = bootstrapTypeName
  }
}

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
  let wasmRuntimeProfile: SwiftWebWasmRuntimeProfile
  let embeddedUnicodeDataTablesLibraryPath: String?
  let nativeActorBootstrapTypeName: String?
  let clientActorBootstrapTypeName: String?
  let appActorCustomConditions: Set<String>
  let appActorUpcomingFeatures: Set<String>
  let appActorExperimentalFeatures: Set<String>
  let actorDependencyTargets: [GeneratedActorDependencyTarget]
}
