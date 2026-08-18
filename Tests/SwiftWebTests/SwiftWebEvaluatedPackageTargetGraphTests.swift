import ActorSystemGeneration
import Foundation
import Testing

@testable import SwiftWebPackageGeneration

@Suite
struct SwiftWebEvaluatedPackageTargetGraphTests {
  @Test
  func explicitDependencyTraitActivatesItsImpliedTargetEdges() throws {
    let graph = try graph(rootRequestedTraits: ["LegacyActors"])

    #expect(
      try graph.directDependencyModuleNames(of: "LegacyProduct")
        == ["ActorSystemDistributed", "ActorSystemCompatibility"]
    )
    #expect(
      graph.target(named: "App")?.sourceDirectory
        == URL(fileURLWithPath: "/fixture/App/AppSources", isDirectory: true)
          .standardizedFileURL
    )
    #expect(
      graph.target(named: "App")?.sourceFiles
        == [URL(fileURLWithPath: "/fixture/App/AppSources/App.swift").standardizedFileURL]
    )
    #expect(graph.target(named: "App")?.customConditions == ["ROOT_ACTORS"])
    #expect(graph.target(named: "App")?.upcomingFeatures == ["RootUpcoming"])
    #expect(graph.target(named: "App")?.experimentalFeatures == ["RootExperimental"])
  }

  @Test
  func defaultActorsTraitDoesNotActivateLegacyCompatibility() throws {
    let graph = try graph(rootRequestedTraits: nil)

    #expect(
      try graph.directDependencyModuleNames(of: "LegacyProduct")
        == ["ActorSystemDistributed"]
    )
  }

  @Test
  func explicitEmptyDependencyTraitsDisableDependencyDefaults() throws {
    let graph = try graph(rootRequestedTraits: [])

    #expect(try graph.directDependencyModuleNames(of: "LegacyProduct").isEmpty)
  }

  @Test
  func packageDescriptionIsTheAuthoritativeTargetSourceSet() throws {
    let graph = try graph(rootRequestedTraits: nil)
    let app = try #require(graph.target(named: "App"))

    #expect(app.sourceFiles.map(\.lastPathComponent) == ["App.swift"])
    #expect(!app.sourceFiles.map(\.lastPathComponent).contains("ExcludedServer.swift"))
  }

  @Test
  func configurationConditionedBuildSettingsAreRejected() throws {
    let root = URL(fileURLWithPath: "/fixture/App", isDirectory: true)
    let manifest = Data(
      """
      {
        "name":"App",
        "products":[{"name":"App","targets":["App"]}],
        "targets":[{
          "name":"App",
          "path":"AppSources",
          "dependencies":[],
          "settings":[{
            "kind":{"define":{"_0":"DEBUG_ONLY"}},
            "condition":{"config":"debug"}
          }]
        }],
        "dependencies":[],
        "traits":[]
      }
      """.utf8
    )
    let description = Data(
      """
      {
        "targets":[{
          "name":"App",
          "path":"AppSources",
          "sources":["App.swift"]
        }]
      }
      """.utf8
    )

    let graph = try SwiftWebEvaluatedPackageTargetGraphLoader.decode(
      manifestDumps: [
        .init(
          identity: "app",
          packageRoot: root,
          data: manifest,
          describedPackageData: description,
          isRoot: true
        )
      ],
      targetEnvironment: try targetEnvironment()
    )
    let app = try #require(graph.target(named: "App"))
    #expect(throws: ActorGenerationError.self) {
      try app.validateGeneratedProjectionCapabilities()
    }
  }

  @Test
  func unreproducibleBuildSettingKindsAreRejected() throws {
    let graph = try singlePackageGraph(
      settingsJSON: """
      [{"kind":{"unsafeFlags":{"_0":["-DUNTRACKED"]}}}]
      """
    )
    let app = try #require(graph.target(named: "App"))
    #expect(throws: ActorGenerationError.self) {
      try app.validateGeneratedProjectionCapabilities()
    }
  }

  @Test
  func unknownConditionFieldsAreRejected() throws {
    let graph = try singlePackageGraph(
      settingsJSON: """
      [{
        "kind":{"define":{"_0":"FUTURE"}},
        "condition":{"futureCondition":true}
      }]
      """
    )
    let app = try #require(graph.target(named: "App"))
    #expect(throws: ActorGenerationError.self) {
      try app.validateGeneratedProjectionCapabilities()
    }
  }

  @Test
  func unreproducibleSettingsOnUnreachableTargetsDoNotBlockTheApp() throws {
    let graph = try singlePackageGraph(
      settingsJSON: "[]",
      supportSettingsJSON: """
      [{"kind":{"linkedFramework":{"_0":"HostOnlyFramework"}}}]
      """
    )
    let app = try #require(graph.target(named: "App"))

    try app.validateGeneratedProjectionCapabilities()
  }

  @Test
  func malformedDependencyConditionsAreRejected() throws {
    #expect(throws: ActorGenerationError.self) {
      _ = try singlePackageGraph(
        dependenciesJSON: #"[{"target":["Support",true]}]"#,
        settingsJSON: "[]"
      )
    }
  }

  @Test
  func productModuleAliasesAreRejectedUntilTheyCanBeReproduced() throws {
    #expect(throws: ActorGenerationError.self) {
      _ = try singlePackageGraph(
        dependenciesJSON: #"[{"product":["SupportProduct","app",{"Support":"AliasedSupport"},null]}]"#,
        settingsJSON: "[]"
      )
    }
  }

  private func graph(
    rootRequestedTraits: [String]?
  ) throws -> SwiftWebEvaluatedPackageTargetGraph {
    let root = URL(fileURLWithPath: "/fixture/App", isDirectory: true)
    let dependency = URL(fileURLWithPath: "/fixture/Legacy", isDirectory: true)
    let requestedTraits: String
    if let rootRequestedTraits {
      requestedTraits = "[" + rootRequestedTraits.map {
        "{\"name\":\"\($0)\"}"
      }.joined(separator: ",") + "]"
    } else {
      requestedTraits = "null"
    }
    let rootDump = Data(
      """
      {
        "name":"App",
        "products":[{"name":"App","targets":["App"]}],
        "targets":[{
          "name":"App",
          "path":"AppSources",
          "dependencies":[{"product":["LegacyProduct","legacy-package",null,null]}],
          "settings":[
            {"kind":{"define":{"_0":"ROOT_ACTORS"}}},
            {"kind":{"enableUpcomingFeature":{"_0":"RootUpcoming"}}},
            {"kind":{"enableExperimentalFeature":{"_0":"RootExperimental"}}}
          ]
        }],
        "dependencies":[{"fileSystem":[{
          "identity":"legacy-package",
          "path":"/fixture/Legacy",
          "traits":\(requestedTraits)
        }]}],
        "traits":[]
      }
      """.utf8
    )
    let dependencyDump = Data(
      """
      {
        "name":"LegacyPackage",
        "products":[{"name":"LegacyProduct","targets":["LegacyProduct"]}],
        "targets":[
          {
            "name":"LegacyProduct",
            "dependencies":[
              {"target":["ActorSystemDistributed",{"traits":["Actors"]}]},
              {"target":["ActorSystemCompatibility",{"traits":["LegacyActors"]}]}
            ],
            "settings":[]
          },
          {"name":"ActorSystemDistributed","dependencies":[],"settings":[]},
          {"name":"ActorSystemCompatibility","dependencies":[],"settings":[]}
        ],
        "dependencies":[],
        "traits":[
          {"name":"default","enabledTraits":["Actors"]},
          {"name":"Actors","enabledTraits":[]},
          {"name":"LegacyActors","enabledTraits":["Actors"]}
        ]
      }
      """.utf8
    )
    let rootDescription = Data(
      """
      {
        "targets":[{
          "name":"App",
          "path":"AppSources",
          "sources":["App.swift"]
        }]
      }
      """.utf8
    )
    let dependencyDescription = Data(
      """
      {
        "targets":[
          {
            "name":"LegacyProduct",
            "path":"Sources/LegacyProduct",
            "sources":["LegacyProduct.swift"]
          },
          {
            "name":"ActorSystemDistributed",
            "path":"Sources/ActorSystemDistributed",
            "sources":["ActorSystemDistributed.swift"]
          },
          {
            "name":"ActorSystemCompatibility",
            "path":"Sources/ActorSystemCompatibility",
            "sources":["ActorSystemCompatibility.swift"]
          }
        ]
      }
      """.utf8
    )
    return try SwiftWebEvaluatedPackageTargetGraphLoader.decode(
      manifestDumps: [
        .init(
          identity: "app",
          packageRoot: root,
          data: rootDump,
          describedPackageData: rootDescription,
          isRoot: true
        ),
        .init(
          identity: "legacy-package",
          packageRoot: dependency,
          data: dependencyDump,
          describedPackageData: dependencyDescription
        ),
      ],
      targetEnvironment: try targetEnvironment()
    )
  }

  private func targetEnvironment() throws -> ActorGenerationTargetEnvironment {
    try ActorGenerationTargetEnvironment(
      availableModules: [],
      operatingSystem: "WASI",
      architecture: "wasm32",
      objectFormat: "wasm",
      pointerBitWidth: 32,
      atomicBitWidths: [8, 16, 32, 64],
      languageVersion: [6],
      compilerVersion: [6, 4]
    )
  }

  private func singlePackageGraph(
    dependenciesJSON: String = "[]",
    settingsJSON: String,
    supportSettingsJSON: String = "[]"
  ) throws -> SwiftWebEvaluatedPackageTargetGraph {
    let root = URL(fileURLWithPath: "/fixture/App", isDirectory: true)
    let manifest = Data(
      """
      {
        "name":"App",
        "products":[{"name":"App","targets":["App"]}],
        "targets":[
          {
            "name":"App",
            "path":"AppSources",
            "dependencies":\(dependenciesJSON),
            "settings":\(settingsJSON)
          },
          {
            "name":"Support",
            "path":"SupportSources",
            "dependencies":[],
            "settings":\(supportSettingsJSON)
          }
        ],
        "dependencies":[],
        "traits":[]
      }
      """.utf8
    )
    let description = Data(
      """
      {
        "targets":[
          {
            "name":"App",
            "path":"AppSources",
            "sources":["App.swift"]
          },
          {
            "name":"Support",
            "path":"SupportSources",
            "sources":["Support.swift"]
          }
        ]
      }
      """.utf8
    )
    return try SwiftWebEvaluatedPackageTargetGraphLoader.decode(
      manifestDumps: [
        .init(
          identity: "app",
          packageRoot: root,
          data: manifest,
          describedPackageData: description,
          isRoot: true
        )
      ],
      targetEnvironment: try targetEnvironment()
    )
  }
}
