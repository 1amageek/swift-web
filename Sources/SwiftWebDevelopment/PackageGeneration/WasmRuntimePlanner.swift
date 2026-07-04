import SwiftHTML
import SwiftWebDevelopmentHooks
import SwiftWebWasmBuild

struct WasmRuntimePlanner: Sendable {
  let appProductName: String
  let splitBuildStrategy: SwiftWebWasmSplitBuildStrategy

  func runtimeTargets(
    for clientComponents: [ClientComponentDeclaration]
  ) -> [WasmRuntimeTargetDeclaration] {
    guard !clientComponents.isEmpty else {
      return []
    }

    let mainTargetName = "\(appProductName)WasmRuntime"
    let mainBundleID = ClientBundleID(
      GeneratedPackageNameFormatter.productName(forWasmRuntimeTarget: mainTargetName)
    )
    let mainComponents = clientComponents.filter { Self.resolvedBundleID(for: $0) == nil }
    var targets: [WasmRuntimeTargetDeclaration] = [
      WasmRuntimeTargetDeclaration(
        targetName: mainTargetName,
        bundleID: mainBundleID,
        componentTypeNames: GeneratedPackageNameFormatter.uniqueTypeNames(
          mainComponents.map(\.typeName)
        ),
        actorContracts: GeneratedPackageNameFormatter.actorContracts(for: mainComponents),
        linkMode: .standalone
      )
    ]

    let splitComponents = Dictionary(
      grouping: clientComponents.compactMap {
        component -> (ClientBundleID, ClientComponentDeclaration)? in
        guard let bundleID = Self.resolvedBundleID(for: component) else {
          return nil
        }
        return (bundleID, component)
      }
    ) { item in
      item.0
    }

    if splitBuildStrategy == .coalescedPolicyBundles {
      let splitPairs = splitComponents.values
        .flatMap { $0.map(\.1) }
      for loadPolicy in Self.coalescedPolicyOrder {
        let policyPairs =
          splitPairs
          .filter { $0.loadPolicy == loadPolicy }
          .sorted { left, right in
            left.typeName < right.typeName
          }
        guard !policyPairs.isEmpty else {
          continue
        }

        let targetName =
          "\(appProductName)\(GeneratedPackageNameFormatter.wasmRuntimeTargetSuffix(for: loadPolicy))WasmRuntime"
        let policyBundleGroups = Dictionary(grouping: policyPairs) { component in
          Self.resolvedBundleID(for: component)
            ?? ClientBundleID(
              GeneratedPackageNameFormatter.productName(forWasmRuntimeTarget: targetName)
            )
        }
        targets.append(
          WasmRuntimeTargetDeclaration(
            targetName: targetName,
            bundleID: ClientBundleID(
              GeneratedPackageNameFormatter.productName(forWasmRuntimeTarget: targetName)
            ),
            componentTypeNames: GeneratedPackageNameFormatter.uniqueTypeNames(
              policyPairs.map(\.typeName)
            ),
            actorContracts: GeneratedPackageNameFormatter.actorContracts(for: policyPairs),
            bundleArtifacts: policyBundleGroups.keys.sorted().map { bundleID in
              let components = policyBundleGroups[bundleID, default: []].sorted { left, right in
                left.typeName < right.typeName
              }
              return WasmRuntimeBundleArtifactDeclaration(
                bundleID: bundleID,
                componentTypeNames: GeneratedPackageNameFormatter.uniqueTypeNames(
                  components.map(\.typeName)
                )
              )
            },
            linkMode: .coalescedStaticFallback
          )
        )
      }
      return targets
    }

    var usedTargetNames = Set<String>()
    usedTargetNames.insert(mainTargetName)
    for bundleID in splitComponents.keys.sorted() {
      let components = splitComponents[bundleID, default: []].map(\.1).sorted { left, right in
        left.typeName < right.typeName
      }
      var targetName = GeneratedPackageNameFormatter.wasmRuntimeTargetName(forBundleID: bundleID)
      var suffix = 2
      while !usedTargetNames.insert(targetName).inserted {
        targetName = "\(GeneratedPackageNameFormatter.wasmRuntimeTargetName(forBundleID: bundleID))\(suffix)"
        suffix += 1
      }
      targets.append(
        WasmRuntimeTargetDeclaration(
          targetName: targetName,
          bundleID: bundleID,
          componentTypeNames: GeneratedPackageNameFormatter.uniqueTypeNames(
            components.map(\.typeName)
          ),
          actorContracts: GeneratedPackageNameFormatter.actorContracts(for: components),
          bundleArtifacts: [
            WasmRuntimeBundleArtifactDeclaration(
              bundleID: bundleID,
              componentTypeNames: GeneratedPackageNameFormatter.uniqueTypeNames(
                components.map(\.typeName)
              )
            )
          ],
          linkMode: .standalone
        )
      )
    }
    return targets
  }

  private static func resolvedBundleID(
    for component: ClientComponentDeclaration
  ) -> ClientBundleID? {
    switch component.bundlePolicy {
    case .main:
      if component.loadPolicy == .eager {
        return nil
      }
      return ClientBundleID("component-\(GeneratedPackageNameFormatter.stableHashHex(component.typeName))")
    case .component:
      return ClientBundleID("component-\(GeneratedPackageNameFormatter.stableHashHex(component.typeName))")
    case .named(let name):
      return ClientBundleID("named-\(GeneratedPackageNameFormatter.stableBundleName(name))")
    case .shared(let name):
      return ClientBundleID("shared-\(GeneratedPackageNameFormatter.stableBundleName(name))")
    }
  }

  private static var coalescedPolicyOrder: [LoadPolicy] {
    [.visible, .interaction, .idle, .manual]
  }
}
