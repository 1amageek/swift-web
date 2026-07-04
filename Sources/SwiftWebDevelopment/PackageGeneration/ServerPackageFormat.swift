import Foundation

struct ServerPackageFormat: GeneratedPackageFormat {
  let packageKind = GeneratedPackageKind.server

  func files(context: GeneratedPackageRenderContext) throws -> [GeneratedFile] {
    [
      GeneratedFile(
        packageKind: packageKind,
        relativePath: "Sources/AppServerLauncher/ServerLauncher.swift",
        contents: Self.serverLauncherSwift(
          context: context,
          installsDevelopmentHooks: false
        )
      ),
      GeneratedFile(
        packageKind: packageKind,
        relativePath: "Package.swift",
        contents: packageSwift(context: context)
      ),
    ]
  }

  static func serverLauncherSwift(
    context: GeneratedPackageRenderContext,
    installsDevelopmentHooks: Bool
  ) -> String {
    let developmentImport =
      installsDevelopmentHooks
      ? "\nimport SwiftWebDevelopmentHooks"
      : ""
    let developmentInstall =
      installsDevelopmentHooks
      ? "\n        SwiftWebDevConsoleLogging.bootstrap()\n        await SwiftWebDevelopmentHooksRuntime.install()\n"
      : ""
    guard let runtimeTarget = context.wasmRuntimeTargets.first else {
      return """
        import \(context.appProductName)
        import SwiftWebVapor\(developmentImport)

        @main
        struct AppServerLauncher {
            static func main() async throws {
        \(developmentInstall)        try await \(context.appProductName).run()
            }
        }
        """
    }

    let productName = GeneratedPackageNameFormatter.productName(
      forWasmRuntimeTarget: runtimeTarget.targetName
    )
    let assetPath = GeneratedPackageNameFormatter.assetPath(
      forWasmRuntimeTarget: runtimeTarget.targetName
    )
    let wasmPackageManifestPath =
      context.layout.wasmPackageDirectory
      .appendingPathComponent("Package.swift")
      .path
    let additionalBundles = context.wasmRuntimeTargets.dropFirst().flatMap { target in
      target.bundleArtifacts.map { bundleArtifact in
        let componentTypeNames = bundleArtifact.componentTypeNames
          .map { "\"\(GeneratedPackageNameFormatter.swiftStringLiteral($0))\"" }
          .joined(separator: ", ")
        return """
                              ClientRuntimeBundleArtifact(
                                  id: "\(bundleArtifact.bundleID.rawValue)",
                                  componentTypeNames: [\(componentTypeNames)],
                                  assetPath: "\(GeneratedPackageNameFormatter.assetPath(forWasmRuntimeTarget: target.targetName))",
                                  artifact: SwiftPMWasmArtifact.location(
                                      anchorFile: "\(GeneratedPackageNameFormatter.swiftStringLiteral(wasmPackageManifestPath))",
                                      target: "\(target.targetName)",
                                      artifactName: "\(GeneratedPackageNameFormatter.productName(forWasmRuntimeTarget: target.targetName))",
                                      scratchDirectory: wasmScratchDirectory
                                  )
                              )
          """
      }
    }
    .joined(separator: ",\n")
    let additionalBundlesArgument =
      additionalBundles.isEmpty
      ? "additionalBundles: []"
      : "additionalBundles: [\n\(additionalBundles)\n                            ]"
    return """
      import \(context.appProductName)
      import Foundation
      import SwiftWebVapor\(developmentImport)

      @main
      struct AppServerLauncher {
          static func main() async throws {
      \(developmentInstall)        let wasmScratchDirectory = ProcessInfo.processInfo.environment["SWIFTWEB_WASM_SCRATCH_PATH"].map {
                  URL(fileURLWithPath: $0, isDirectory: true)
              }

              try await \(context.appProductName).run(
                  clientRuntime: .wasm(
                      id: "\(productName)",
                      assetPath: "\(assetPath)",
                      artifact: SwiftPMWasmArtifact.location(
                          anchorFile: "\(GeneratedPackageNameFormatter.swiftStringLiteral(wasmPackageManifestPath))",
                          target: "\(runtimeTarget.targetName)",
                          artifactName: "\(productName)",
                          scratchDirectory: wasmScratchDirectory
                      ),
                      \(additionalBundlesArgument),
                      metricsMode: .detailed
                  )
              )
          }
      }
      """
  }

  private func packageSwift(context: GeneratedPackageRenderContext) -> String {
    let appDependencyPath = GeneratedPackageNameFormatter.relativePath(
      from: context.layout.serverPackageDirectory,
      to: context.layout.appPackageDirectory
    )
    let swiftWebDependencyPath = GeneratedPackageNameFormatter.relativePath(
      from: context.layout.serverPackageDirectory,
      to: context.swiftWebPackageDirectory
    )
    return """
      // swift-tools-version: 6.3

      import PackageDescription

      let swiftSettings: [SwiftSetting] = [
          .enableUpcomingFeature("ApproachableConcurrency"),
      ]

      let appServerTarget = Target.executableTarget(
          name: "AppServerLauncher",
          dependencies: [
              .product(name: "\(context.appProductName)", package: "\(context.appPackageDependencyName)"),
              .product(name: "SwiftWebVapor", package: "swift-web"),
          ],
          path: "Sources/AppServerLauncher",
          swiftSettings: swiftSettings
      )

      let package = Package(
          name: "\(context.appPackageName)ServerGenerated",
          platforms: [
              .macOS("26.2"),
          ],
          products: [
              .executable(name: "\(context.serverProductName)", targets: ["AppServerLauncher"]),
          ],
          dependencies: [
              .package(path: "\(GeneratedPackageNameFormatter.swiftStringLiteral(appDependencyPath))"),
              .package(path: "\(GeneratedPackageNameFormatter.swiftStringLiteral(swiftWebDependencyPath))"),
          ],
          targets: [
              appServerTarget,
          ],
          swiftLanguageModes: [.v6]
      )
      """
  }
}
