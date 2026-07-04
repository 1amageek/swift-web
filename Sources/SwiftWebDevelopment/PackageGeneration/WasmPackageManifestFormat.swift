struct WasmPackageManifestFormat {
  func packageSwift(context: GeneratedPackageRenderContext) -> String {
    let targetNames = context.wasmRuntimeTargets.map(\.targetName)
    switch context.wasmRuntimeProfile {
    case .standard:
      return standardWasmPackageSwift(
        appPackageName: context.appPackageName,
        appProductName: context.appProductName,
        wasmRuntimeTargetNames: targetNames,
        actorRuntimeDependencyDeclaration: context.actorRuntimeDependencyDeclaration
      )
    case .embedded:
      return embeddedWasmPackageSwift(
        appPackageName: context.appPackageName,
        wasmRuntimeTargetNames: targetNames
      )
    }
  }

  private func standardWasmPackageSwift(
    appPackageName: String,
    appProductName: String,
    wasmRuntimeTargetNames: [String],
    actorRuntimeDependencyDeclaration: String
  ) -> String {
    wasmPackageSwiftContents(
      appPackageName: appPackageName,
      wasmRuntimeTargetNames: wasmRuntimeTargetNames,
      targetDeclarations: wasmRuntimeTargetNames.map { targetName in
        standardWasmRuntimeTargetDeclaration(targetName: targetName, appProductName: appProductName)
      },
      supportTargetDeclarations: [
        """
        let appClientTarget = Target.target(
            name: "\(appProductName)",
            dependencies: [
                "SwiftHTML",
                "SwiftWebActors",
                "SwiftWebUI",
                "SwiftWebUIRuntime",
            ],
            path: "Sources/\(appProductName)",
            swiftSettings: swiftSettings
        )
        """,
        """
        let swiftHTMLTarget = Target.target(
            name: "SwiftHTML",
            path: "Sources/SwiftHTML",
            swiftSettings: swiftSettings
        )
        """,
        """
        let swiftWebActorsTarget = Target.target(
            name: "SwiftWebActors",
            dependencies: [
                .product(name: "ActorRuntime", package: "swift-actor-runtime"),
            ],
            path: "Sources/SwiftWebActors",
            swiftSettings: swiftSettings
        )
        """,
        """
        let swiftWebStyleTarget = Target.target(
            name: "SwiftWebStyle",
            dependencies: [
                "SwiftHTML",
            ],
            path: "Sources/SwiftWebStyle",
            swiftSettings: swiftSettings
        )
        """,
        """
        let swiftWebUIThemeTarget = Target.target(
            name: "SwiftWebUITheme",
            dependencies: [
                "SwiftHTML",
                "SwiftWebStyle",
            ],
            path: "Sources/SwiftWebUITheme",
            swiftSettings: swiftSettings
        )
        """,
        """
        let swiftWebUITarget = Target.target(
            name: "SwiftWebUI",
            dependencies: [
                "SwiftHTML",
                "SwiftWebActors",
                "SwiftWebStyle",
                "SwiftWebUITheme",
            ],
            path: "Sources/SwiftWebUI",
            swiftSettings: swiftSettings
        )
        """,
        javaScriptKitTargetDeclarations(),
        """
        let swiftWebUIRuntimeTarget = Target.target(
            name: "SwiftWebUIRuntime",
            dependencies: [
                "SwiftHTML",
                "JavaScriptKit",
                "SwiftWebActors",
                "SwiftWebStyle",
            ],
            path: "Sources/SwiftWebUIRuntime",
            swiftSettings: swiftSettings
        )
        """,
      ],
      supportTargets: [
        "cJavaScriptKitTarget",
        "javaScriptKitTarget",
        "swiftHTMLTarget",
        "swiftWebActorsTarget",
        "swiftWebStyleTarget",
        "swiftWebUIThemeTarget",
        "swiftWebUITarget",
        "swiftWebUIRuntimeTarget",
        "appClientTarget",
      ],
      dependencies: [actorRuntimeDependencyDeclaration]
    )
  }

  private func embeddedWasmPackageSwift(
    appPackageName: String,
    wasmRuntimeTargetNames: [String]
  ) -> String {
    wasmPackageSwiftContents(
      appPackageName: appPackageName,
      wasmRuntimeTargetNames: wasmRuntimeTargetNames,
      targetDeclarations: wasmRuntimeTargetNames.map(embeddedWasmRuntimeTargetDeclaration),
      supportTargetDeclarations: [
        javaScriptKitTargetDeclarations(),
        """
        let swiftHTMLClientRuntimeTarget = Target.target(
            name: "SwiftHTMLClientRuntime",
            path: "Sources/SwiftHTMLClientRuntime",
            swiftSettings: swiftSettings
        )
        """,
      ],
      supportTargets: [
        "cJavaScriptKitTarget",
        "javaScriptKitTarget",
        "swiftHTMLClientRuntimeTarget",
      ],
      dependencies: []
    )
  }

  private func wasmPackageSwiftContents(
    appPackageName: String,
    wasmRuntimeTargetNames: [String],
    targetDeclarations: [String],
    supportTargetDeclarations: [String],
    supportTargets: [String],
    dependencies: [String]
  ) -> String {
    let wasmTargetDeclarations = targetDeclarations.joined(separator: "\n\n")
    let wasmProductDeclarations =
      wasmRuntimeTargetNames
      .map { targetName in
        ".executable(name: \"\(GeneratedPackageNameFormatter.productName(forWasmRuntimeTarget: targetName))\", targets: [\"\(targetName)\"])"
      }
      .joined(separator: ",\n        ")
    let wasmTargets = (supportTargets + wasmRuntimeTargetNames.map(GeneratedPackageNameFormatter.variableName(for:)))
      .map { "        \($0)" }
      .joined(separator: ",\n")
    let dependencyDeclarations =
      dependencies.isEmpty
      ? ""
      : "\n          \(dependencies.joined(separator: ",\n          ")),\n      "
    let supportDeclarations = supportTargetDeclarations.joined(separator: "\n\n")
    return """
      // swift-tools-version: 6.3

      import PackageDescription

      let swiftSettings: [SwiftSetting] = [
          .enableUpcomingFeature("ApproachableConcurrency"),
      ]
      let wasmSwiftSettings: [SwiftSetting] = swiftSettings + [
          .enableExperimentalFeature("Extern"),
          .unsafeFlags(["-Xclang-linker", "-mexec-model=reactor"]),
      ]
      let wasmLinkerSettings: [LinkerSetting] = [
          .unsafeFlags([
              // The hydration/render walk recurses through the component tree; the
              // default wasm stack (1 MB) overflows on deep trees and traps with
              // "memory access out of bounds". Give it generous headroom.
              "-Xlinker", "-z", "-Xlinker", "stack-size=16777216",
              "-Xlinker", "--export=swiftweb_alloc",
              "-Xlinker", "--export=swiftweb_dealloc",
              "-Xlinker", "--export=swiftweb_bootstrap",
              "-Xlinker", "--export=swiftweb_dispatch_event",
              "-Xlinker", "--export=swiftweb_snapshot_state",
              "-Xlinker", "--export=swiftweb_restore_state",
              "-Xlinker", "--export=swiftweb_response_ptr",
              "-Xlinker", "--export=swiftweb_response_len",
              "-Xlinker", "--export=swiftweb_response_free",
          ]),
      ]

      \(supportDeclarations)

      \(wasmTargetDeclarations)

      let package = Package(
          name: "\(appPackageName)WasmGenerated",
          platforms: [
              .macOS("26.2"),
          ],
          products: [
              \(wasmProductDeclarations)
          ],
          dependencies: [\(dependencyDeclarations)],
          targets: [
      \(wasmTargets)
          ],
          swiftLanguageModes: [.v6]
      )
      """
  }

  private func standardWasmRuntimeTargetDeclaration(
    targetName: String,
    appProductName: String
  ) -> String {
    """
    let \(GeneratedPackageNameFormatter.variableName(for: targetName)) = Target.executableTarget(
        name: "\(targetName)",
        dependencies: [
            "\(appProductName)",
            "SwiftWebActors",
            "SwiftHTML",
            "SwiftWebUI",
            "SwiftWebUIRuntime",
        ],
        path: "Sources/\(targetName)",
        swiftSettings: wasmSwiftSettings,
        linkerSettings: wasmLinkerSettings
    )
    """
  }

  private func embeddedWasmRuntimeTargetDeclaration(targetName: String) -> String {
    """
    let \(GeneratedPackageNameFormatter.variableName(for: targetName)) = Target.executableTarget(
        name: "\(targetName)",
        dependencies: [
            "SwiftHTMLClientRuntime",
            "JavaScriptKit",
        ],
        path: "Sources/\(targetName)",
        swiftSettings: wasmSwiftSettings,
        linkerSettings: wasmLinkerSettings
    )
    """
  }

  private func javaScriptKitTargetDeclarations() -> String {
    """
    let cJavaScriptKitTarget = Target.target(
        name: "_CJavaScriptKit",
        path: "Sources/_CJavaScriptKit"
    )

    let javaScriptKitTarget = Target.target(
        name: "JavaScriptKit",
        dependencies: [
            "_CJavaScriptKit",
        ],
        path: "Sources/JavaScriptKit",
        swiftSettings: [
            .enableExperimentalFeature("Extern"),
        ]
    )
    """
  }
}
