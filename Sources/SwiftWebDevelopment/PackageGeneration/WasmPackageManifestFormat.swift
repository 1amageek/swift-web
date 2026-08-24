import ActorSystemGeneration
import SwiftWebWasmBuild

struct WasmPackageManifestFormat {
  func packageSwift(context: GeneratedPackageRenderContext) throws -> String {
    if context.wasmRuntimeTargets.isEmpty && context.actorDependencyTargets.isEmpty {
      return emptyPackageSwift(appPackageName: context.appPackageName)
    }
    let targetNames = context.wasmRuntimeTargets.map(\.targetName)
    return try wasmPackageSwift(
      appPackageName: context.appPackageName,
      appProductName: context.appProductName,
      wasmRuntimeTargetNames: targetNames,
      actorDependencyTargets: context.actorDependencyTargets,
      appActorCustomConditions: context.appActorCustomConditions,
      appActorUpcomingFeatures: context.appActorUpcomingFeatures,
      appActorExperimentalFeatures: context.appActorExperimentalFeatures,
      profile: context.wasmRuntimeProfile,
      embeddedUnicodeDataTablesLibraryPath: context.embeddedUnicodeDataTablesLibraryPath
    )
  }

  private func emptyPackageSwift(appPackageName: String) -> String {
    """
    // swift-tools-version: 6.4

    import PackageDescription

    let package = Package(
        name: "\(appPackageName)WasmGenerated",
        platforms: [
            .macOS("26.2"),
        ],
        products: [],
        targets: [],
        swiftLanguageModes: [.v6]
    )
    """
  }

  private func wasmPackageSwift(
    appPackageName: String,
    appProductName: String,
    wasmRuntimeTargetNames: [String],
    actorDependencyTargets: [GeneratedActorDependencyTarget],
    appActorCustomConditions: Set<String>,
    appActorUpcomingFeatures: Set<String>,
    appActorExperimentalFeatures: Set<String>,
    profile: SwiftWebWasmRuntimeProfile,
    embeddedUnicodeDataTablesLibraryPath: String?
  ) throws -> String {
    let actorRuntimeTargetName = switch profile {
    case .standard:
      "ActorSystemDistributed"
    case .embedded:
      "ActorSystemEmbedded"
    }
    let actorRuntimeDependencies: [String] = switch profile {
    case .standard:
      [
        "\"ActorSystemCore\"",
        "\"ActorSystemDistributed\"",
        "\"SwiftHTML\"",
      ]
    case .embedded:
      [
        "\"ActorSystemCore\"",
        "\"ActorSystemEmbedded\"",
        "\"SwiftHTML\"",
      ]
    }
    let packageDependencies: [String] = []
    let appActorDependencyLines = actorDependencyTargets.isEmpty
      ? ""
      : "\n" + actorDependencyTargets
        .map { "                \"\($0.moduleName)\"," }
        .joined(separator: "\n")
    let actorDependencyTargetDeclarations = actorDependencyTargets.map {
      actorDependencyTargetDeclaration(
        target: $0,
        runtimeTargetName: actorRuntimeTargetName
      )
    }
    return try wasmPackageSwiftContents(
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
                "ActorSystemCore",
                "\(actorRuntimeTargetName)",
                "JavaScriptKit",
                "SwiftHTML",
                "SwiftWebActors",
                "SwiftWebStyle",
                "SwiftWebUI",
                "SwiftWebUIRuntime",
                "SwiftWebUITheme",\(appActorDependencyLines)
            ],
            path: "Sources/\(appProductName)",
            swiftSettings: appActorSwiftSettings
        )
        """,
        """
        let swiftHTMLTarget = Target.target(
            name: "SwiftHTML",
            path: "Sources/SwiftHTML",
            swiftSettings: swiftHTMLSwiftSettings
        )
        """,
        """
        let swiftWebActorsTarget = Target.target(
            name: "SwiftWebActors",
            dependencies: [
        \(actorRuntimeDependencies.map { "        \($0)," }.joined(separator: "\n"))
            ],
            path: "Sources/SwiftWebActors",
            swiftSettings: actorSwiftSettings
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
        actorSystemTargetDeclarations(runtimeTargetName: actorRuntimeTargetName),
      ] + actorDependencyTargetDeclarations + [
        """
        let swiftWebUIRuntimeTarget = Target.target(
            name: "SwiftWebUIRuntime",
            dependencies: [
                "ActorSystemCore",
                "\(actorRuntimeTargetName)",
                "SwiftHTML",
                "JavaScriptKit",
                "SwiftWebActors",
                "SwiftWebStyle",
            ],
            path: "Sources/SwiftWebUIRuntime",
            swiftSettings: actorSwiftSettings
        )
        """,
      ],
      supportTargets: [
        "cJavaScriptKitTarget",
        "javaScriptKitTarget",
        "cJavaScriptEventLoopTarget",
        "javaScriptEventLoopTarget",
        "actorSystemCoreTarget",
        "actorSystemRuntimeTarget",
        "swiftHTMLTarget",
        "swiftWebActorsTarget",
        "swiftWebStyleTarget",
        "swiftWebUIThemeTarget",
        "swiftWebUITarget",
        "swiftWebUIRuntimeTarget",
        "appClientTarget",
      ] + actorDependencyTargets.map {
        GeneratedPackageNameFormatter.variableName(for: $0.moduleName)
      },
      dependencies: packageDependencies,
      appActorCustomConditions: appActorCustomConditions,
      appActorUpcomingFeatures: appActorUpcomingFeatures,
      appActorExperimentalFeatures: appActorExperimentalFeatures,
      actorDependencyTargets: actorDependencyTargets,
      profile: profile,
      embeddedUnicodeDataTablesLibraryPath: embeddedUnicodeDataTablesLibraryPath
    )
  }

  private func wasmPackageSwiftContents(
    appPackageName: String,
    wasmRuntimeTargetNames: [String],
    targetDeclarations: [String],
    supportTargetDeclarations: [String],
    supportTargets: [String],
    dependencies: [String],
    appActorCustomConditions: Set<String>,
    appActorUpcomingFeatures: Set<String>,
    appActorExperimentalFeatures: Set<String>,
    actorDependencyTargets: [GeneratedActorDependencyTarget],
    profile: SwiftWebWasmRuntimeProfile,
    embeddedUnicodeDataTablesLibraryPath: String?
  ) throws -> String {
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
    let actorProfile: ActorGenerationProfile = switch profile {
    case .standard: .standardClient
    case .embedded: .embeddedClient
    }
    let actorDefinitions = SwiftWebActorProjection.generatedCustomConditions(
      profile: actorProfile,
      role: .actorDependency
    ).sorted()
    let actorSwiftSettings = actorDefinitions.isEmpty
      ? "let actorSwiftSettings: [SwiftSetting] = swiftSettings"
      : """
        let actorSwiftSettings: [SwiftSetting] = swiftSettings + [
        \(actorDefinitions.map { "    .define(\"\($0)\")," }.joined(separator: "\n"))
        ]
        """
    let targetActorSwiftSettings = [
      actorTargetSwiftSettingsDeclaration(
        variableName: "appActorSwiftSettings",
        customConditions: appActorCustomConditions,
        upcomingFeatures: appActorUpcomingFeatures,
        experimentalFeatures: appActorExperimentalFeatures,
        baselineCustomConditions: Set(actorDefinitions)
      ),
    ] + actorDependencyTargets.map { target in
      actorTargetSwiftSettingsDeclaration(
        variableName: actorSwiftSettingsVariableName(for: target.moduleName),
        customConditions: target.customConditions,
        upcomingFeatures: target.upcomingFeatures,
        experimentalFeatures: target.experimentalFeatures,
        baselineCustomConditions: Set(actorDefinitions)
      )
    }
    let embeddedUnicodeLinkerFlags: String
    switch profile {
    case .standard:
      embeddedUnicodeLinkerFlags = ""
    case .embedded:
      guard let embeddedUnicodeDataTablesLibraryPath else {
        throw ActorGenerationError.invalidTargetEnvironment(
          reason: "Embedded WASM rendering requires the pinned Unicode data tables archive"
        )
      }
      embeddedUnicodeLinkerFlags = """

              "-Xlinker", "\(GeneratedPackageNameFormatter.swiftStringLiteral(embeddedUnicodeDataTablesLibraryPath))",
        """
    }
    return """
      // swift-tools-version: 6.4

      import PackageDescription

      let swiftSettings: [SwiftSetting] = [
          .enableUpcomingFeature("ApproachableConcurrency"),
      ]
      \(actorSwiftSettings)
      \(targetActorSwiftSettings.joined(separator: "\n"))
      let wasmSwiftSettings: [SwiftSetting] = swiftSettings + [
          .enableExperimentalFeature("Extern"),
          .unsafeFlags(["-Xclang-linker", "-mexec-model=reactor"]),
      ]
      let swiftHTMLSwiftSettings: [SwiftSetting] = swiftSettings + [
          .enableExperimentalFeature("Extern"),
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
              "-Xlinker", "--export=swiftweb_shutdown",
              "-Xlinker", "--export=swiftweb_shutdown_status",
              "-Xlinker", "--export=swiftweb_start",
              "-Xlinker", "--export=swiftweb_start_status",
              "-Xlinker", "--export=swiftweb_dispatch_event",
              "-Xlinker", "--export=swiftweb_snapshot_state",
              "-Xlinker", "--export=swiftweb_restore_state",
              "-Xlinker", "--export=swiftweb_response_len",
              "-Xlinker", "--export=swiftweb_response_copy",
              "-Xlinker", "--export=swiftweb_response_free",\(embeddedUnicodeLinkerFlags)
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
            "JavaScriptEventLoop",
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

    let cJavaScriptEventLoopTarget = Target.target(
        name: "_CJavaScriptEventLoop",
        path: "Sources/_CJavaScriptEventLoop"
    )

    let javaScriptEventLoopTarget = Target.target(
        name: "JavaScriptEventLoop",
        dependencies: [
            "JavaScriptKit",
            "_CJavaScriptEventLoop",
        ],
        path: "Sources/JavaScriptEventLoop",
        swiftSettings: swiftSettings
    )
    """
  }

  private func actorSystemTargetDeclarations(runtimeTargetName: String) -> String {
    """
    let actorSystemCoreTarget = Target.target(
        name: "ActorSystemCore",
        path: "Sources/ActorSystemCore",
        swiftSettings: swiftSettings
    )

    let actorSystemRuntimeTarget = Target.target(
        name: "\(runtimeTargetName)",
        dependencies: [
            "ActorSystemCore",
        ],
        path: "Sources/\(runtimeTargetName)",
        swiftSettings: swiftSettings
    )
    """
  }

  private func actorDependencyTargetDeclaration(
    target: GeneratedActorDependencyTarget,
    runtimeTargetName: String
  ) -> String {
    let generatedTargetModules: Set<String> = [
      "ActorSystemCore",
      runtimeTargetName,
      "JavaScriptKit",
      "JavaScriptEventLoop",
      "SwiftHTML",
      "SwiftWebActors",
      "SwiftWebStyle",
      "SwiftWebUI",
      "SwiftWebUIRuntime",
      "SwiftWebUITheme",
    ]
    var dependencies = [
      "\"ActorSystemCore\"",
      "\"\(runtimeTargetName)\"",
      "\"SwiftWebActors\"",
    ]
    dependencies.append(
      contentsOf: target.clientImportedModuleNames
        .filter(generatedTargetModules.contains)
        .map { "\"\($0)\"" }
    )
    dependencies.append(
      contentsOf: target.dependencyModuleNames.map { "\"\($0)\"" }
    )
    var seenDependencies = Set<String>()
    let dependencyLines = dependencies
      .filter { seenDependencies.insert($0).inserted }
      .map { "            \($0)," }
      .joined(separator: "\n")
    return """
    let \(GeneratedPackageNameFormatter.variableName(for: target.moduleName)) = Target.target(
        name: "\(target.moduleName)",
        dependencies: [
    \(dependencyLines)
        ],
        path: "Sources/\(target.moduleName)",
        swiftSettings: \(actorSwiftSettingsVariableName(for: target.moduleName))
    )
    """
  }

  private func actorTargetSwiftSettingsDeclaration(
    variableName: String,
    customConditions: Set<String>,
    upcomingFeatures: Set<String>,
    experimentalFeatures: Set<String>,
    baselineCustomConditions: Set<String>
  ) -> String {
    let settings = customConditions.subtracting(baselineCustomConditions).sorted().map {
      ".define(\(swiftLiteral($0)))"
    } + upcomingFeatures.subtracting(["ApproachableConcurrency"]).sorted().map {
      ".enableUpcomingFeature(\(swiftLiteral($0)))"
    } + experimentalFeatures.sorted().map {
      ".enableExperimentalFeature(\(swiftLiteral($0)))"
    }
    guard !settings.isEmpty else {
      return "let \(variableName): [SwiftSetting] = actorSwiftSettings"
    }
    return """
    let \(variableName): [SwiftSetting] = actorSwiftSettings + [
    \(settings.map { "    \($0)," }.joined(separator: "\n"))
    ]
    """
  }

  private func actorSwiftSettingsVariableName(for moduleName: String) -> String {
    "\(GeneratedPackageNameFormatter.variableName(for: moduleName))SwiftSettings"
  }

  private func swiftLiteral(_ value: String) -> String {
    var literal = "\""
    for character in value {
      switch character {
      case "\\": literal += "\\\\"
      case "\"": literal += "\\\""
      case "\n": literal += "\\n"
      case "\r": literal += "\\r"
      case "\t": literal += "\\t"
      default: literal.append(character)
      }
    }
    literal += "\""
    return literal
  }
}
