import Foundation
import Synchronization
import Testing

@testable import SwiftWebPackageGeneration
@testable import SwiftWebWasmBuild

@Suite
struct SwiftWebGeneratedPackageMaterializerTests {
  @Test
  func materializesGeneratedBuildPackage() throws {
    let root = FileManager.default.temporaryDirectory
      .appendingPathComponent(
        "SwiftWebGeneratedPackageMaterializerTests-\(UUID().uuidString)", isDirectory: true)
    defer {
      do {
        try FileManager.default.removeItem(at: root)
      } catch {}
    }

    let swiftWebPackage = root.appendingPathComponent("swift-web", isDirectory: true)
    let swiftHTMLPackage = root.appendingPathComponent("swift-html", isDirectory: true)
    let appPackage = root.appendingPathComponent("SampleApp", isDirectory: true)
    try write(
      """
      // swift-tools-version: 6.3
      import PackageDescription

      let package = Package(
          name: "swift-html",
          products: [
              .library(name: "SwiftHTML", targets: ["SwiftHTML"]),
          ],
          targets: [
              .target(name: "SwiftHTML"),
          ]
      )
      """,
      to: swiftHTMLPackage.appendingPathComponent("Package.swift")
    )
    try writeSwiftHTMLRuntimeSources(in: swiftHTMLPackage)
    try write(
      """
      // swift-tools-version: 6.3
      import PackageDescription

      let package = Package(
          name: "swift-web",
          products: [
              .library(name: "SwiftWebActors", targets: ["SwiftWebActors"]),
              .library(name: "SwiftWebStyle", targets: ["SwiftWebStyle"]),
              .library(name: "SwiftWebUI", targets: ["SwiftWebUI"]),
              .library(name: "SwiftWebUIRuntime", targets: ["SwiftWebUIRuntime"]),
              .library(name: "SwiftWebCore", targets: ["SwiftWebCore"]),
              .library(name: "SwiftWeb", targets: ["SwiftWeb"]),
              .library(name: "SwiftWebHTTPServerHost", targets: ["SwiftWebHTTPServerHost"]),
          ],
          dependencies: [
              .package(path: "\(swiftHTMLPackage.path)"),
          ],
          targets: [
              .target(name: "SwiftWebActors"),
              .target(name: "SwiftWebStyle"),
              .target(name: "SwiftWebUI"),
              .target(name: "SwiftWebUIRuntime"),
              .target(name: "SwiftWebCore"),
              .target(name: "SwiftWeb"),
              .target(name: "SwiftWebHTTPServerHost"),
          ]
      )
      """,
      to: swiftWebPackage.appendingPathComponent("Package.swift")
    )
    try writeSwiftWebStyleRuntimeSources(in: swiftWebPackage)
    try writeSwiftWebUIThemeRuntimeSources(in: swiftWebPackage)
    try write(
      "import SwiftHTML\npublic struct Text {}",
      to: swiftWebPackage.appendingPathComponent("Sources/SwiftWebUI/Components/Text.swift")
    )
    try write(
      "public struct WebActorSystem {}",
      to: swiftWebPackage.appendingPathComponent("Sources/SwiftWebRuntime/Actors/WebActorSystem.swift")
    )
    try write(
      "import SwiftHTML\npublic struct RuntimeEntrypoint {}",
      to: swiftWebPackage.appendingPathComponent(
        "Sources/SwiftWebBrowser/ClientRuntime/RuntimeEntrypoint.swift")
    )
    try writeJavaScriptKitRuntimeCheckout(in: swiftWebPackage)
    try write(
      """
      // swift-tools-version: 6.3
      import PackageDescription

      let package = Package(
          name: "SampleApp",
          products: [
              .library(name: "SampleApp", targets: ["SampleApp"]),
          ],
          dependencies: [
              .package(path: "\(swiftWebPackage.path)"),
          ],
          targets: [
              .target(name: "SampleApp"),
          ]
      )
      """,
      to: appPackage.appendingPathComponent("Package.swift")
    )
    try write(
      "public struct SampleApp {}",
      to: appPackage.appendingPathComponent("Sources/SampleApp/App.swift"))
    try write(
      """
      public struct ClientSample: ClientComponent {
          @Actor private var service: any SampleServiceProtocol

          public init() {}
      }
      """,
      to: appPackage.appendingPathComponent("Sources/SampleApp/ClientSample.swift")
    )
    try write(
      "public struct ClientBadge: ClientComponent { public init() {} }",
      to: appPackage.appendingPathComponent("Sources/SampleApp/ClientBadge.swift")
    )
    try write(
      """
      public struct ClientExtensionBox {
          public init() {}
      }

      extension ClientExtensionBox: ClientComponent {}
      """,
      to: appPackage.appendingPathComponent("Sources/SampleApp/ClientExtensionBox.swift")
    )
    try write(
      """
      @Resolvable
      protocol SampleServiceProtocol: DistributedActor
      where ActorSystem == WebActorSystem {
          distributed func ping() async throws -> String
      }
      """,
      to: appPackage.appendingPathComponent(
        "Sources/SampleApp/Services/SampleServiceProtocol.swift")
    )
    try write(
      "struct Page {}", to: appPackage.appendingPathComponent("Sources/SampleApp/Routes/Page.swift")
    )
    try write(
      "struct Service {}",
      to: appPackage.appendingPathComponent("Sources/SampleApp/Actions/Service.swift"))
    try write(
      """
      {
        "pins" : [
          {
            "identity" : "javascriptkit",
            "kind" : "remoteSourceControl",
            "location" : "https://github.com/swiftwasm/JavaScriptKit.git",
            "state" : {
              "revision" : "abc",
              "version" : "0.55.0"
            }
          },
          {
            "identity" : "swift-syntax",
            "kind" : "remoteSourceControl",
            "location" : "https://github.com/swiftlang/swift-syntax.git",
            "state" : {
              "revision" : "def",
              "version" : "602.0.0"
            }
          },
          {
            "identity" : "vapor",
            "kind" : "remoteSourceControl",
            "location" : "https://github.com/vapor/vapor.git",
            "state" : {
              "revision" : "ghi"
            }
          },
          {
            "identity" : "swift-actor-runtime",
            "kind" : "remoteSourceControl",
            "location" : "https://github.com/1amageek/swift-actor-runtime.git",
            "state" : {
              "revision" : "jkl",
              "version" : "0.6.0"
            }
          }
        ],
        "version" : 3
      }
      """,
      to: appPackage.appendingPathComponent("Package.resolved")
    )
    try write(
      "import SampleApp\n@main struct Runtime { static func main() {} }",
      to: appPackage.appendingPathComponent(
        ".swiftweb/generated/Sources/SampleWasmRuntime/Runtime.swift")
    )
    try write(
      "legacy", to: appPackage.appendingPathComponent(".swiftweb/generated/.materialize.lock"))

    let generatedPackage = try SwiftWebGeneratedPackageMaterializer(
      appPackageDirectory: appPackage,
      wasmSplitBuildStrategy: .resolvedBundles
    )
    .materialize()

    #expect(generatedPackage.appProductName == "SampleApp")
    #expect(generatedPackage.serverProductName == "app-server")
    #expect(generatedPackage.developmentServerProductName == "app-server-dev")
    #expect(generatedPackage.devProductName == "SampleApp-dev")
    #expect(generatedPackage.wasmProductNames == ["sample-app-wasm-runtime"])
    #expect(generatedPackage.packageDirectory.lastPathComponent == "server")
    #expect(generatedPackage.devPackageDirectory.lastPathComponent == "dev")
    #expect(generatedPackage.wasmPackageDirectory.lastPathComponent == "wasm")
    #expect(
      !FileManager.default.fileExists(
        atPath: generatedPackage.rootDirectory.appendingPathComponent(".materialize.lock").path
      ))

    let serverPackageSwift = try String(
      contentsOf: generatedPackage.packageDirectory.appendingPathComponent("Package.swift"),
      encoding: .utf8
    )
    let wasmPackageSwift = try String(
      contentsOf: generatedPackage.wasmPackageDirectory.appendingPathComponent("Package.swift"),
      encoding: .utf8
    )
    let devPackageSwift = try String(
      contentsOf: generatedPackage.devPackageDirectory.appendingPathComponent("Package.swift"),
      encoding: .utf8
    )
    #expect(
      FileManager.default.fileExists(
        atPath: generatedPackage.packageDirectory.appendingPathComponent("Package.resolved").path
      ))
    #expect(
      FileManager.default.fileExists(
        atPath: generatedPackage.devPackageDirectory.appendingPathComponent("Package.resolved").path
      ))
    #expect(
      FileManager.default.fileExists(
        atPath: generatedPackage.wasmPackageDirectory.appendingPathComponent("Package.resolved")
          .path
      ))
    let wasmPackageResolved = try String(
      contentsOf: generatedPackage.wasmPackageDirectory.appendingPathComponent("Package.resolved"),
      encoding: .utf8
    )
    #expect(!wasmPackageResolved.contains("javascriptkit"))
    #expect(!wasmPackageResolved.contains("swift-syntax"))
    #expect(!wasmPackageResolved.contains("vapor"))
    #expect(wasmPackageResolved.contains("swift-actor-runtime"))
    #expect(
      serverPackageSwift.contains(
        ".executable(name: \"app-server\", targets: [\"AppServerLauncher\"])"))
    #expect(serverPackageSwift.contains(#".package(path: "../../..")"#))
    #expect(serverPackageSwift.contains(#".package(path: "../../../../swift-web"),"#))
    #expect(
      !serverPackageSwift.contains(
        ".executable(name: \"SampleApp-dev\", targets: [\"SwiftWebDevLauncher\"])"))
    #expect(!serverPackageSwift.contains(".package(path: \"\(swiftWebPackage.path)\""))
    #expect(!serverPackageSwift.contains(swiftWebPackage.path))
    #expect(!serverPackageSwift.contains("https://github.com/1amageek/swift-web.git"))
    #expect(!serverPackageSwift.contains("SwiftWebDevLauncher"))
    #expect(!serverPackageSwift.contains("SwiftWebDevelopment"))
    #expect(!serverPackageSwift.contains("AppDevelopmentServerLauncher"))
    #expect(!serverPackageSwift.contains("sample-wasm-runtime"))
    #expect(!serverPackageSwift.contains("JavaScriptKit"))
    #expect(!serverPackageSwift.contains("swift-actor-runtime"))

    #expect(
      devPackageSwift.contains(
        ".executable(name: \"SampleApp-dev\", targets: [\"SwiftWebDevLauncher\"])"))
    #expect(
      devPackageSwift.contains(
        ".executable(name: \"app-server-dev\", targets: [\"AppDevelopmentServerLauncher\"])"))
    #expect(!devPackageSwift.contains(".package(path: \"\(swiftWebPackage.path)\""))
    #expect(!devPackageSwift.contains(swiftWebPackage.path))
    #expect(!devPackageSwift.contains("https://github.com/1amageek/swift-web.git"))
    #expect(devPackageSwift.contains(#".package(path: "../../../../swift-web")"#))
    #expect(devPackageSwift.contains(#".package(path: "../../..")"#))
    #expect(
      devPackageSwift.contains(".product(name: \"SwiftWebDevelopment\", package: \"swift-web\")"))
    #expect(
      devPackageSwift.contains(".product(name: \"SwiftWebHTTPServerHost\", package: \"swift-web\")"))
    #expect(
      devPackageSwift.contains(
        ".product(name: \"SwiftWebDevelopmentHooks\", package: \"swift-web\")"))
    #expect(!devPackageSwift.contains("sample-wasm-runtime"))

    #expect(
      wasmPackageSwift.contains(
        ".executable(name: \"sample-app-wasm-runtime\", targets: [\"SampleAppWasmRuntime\"])"))
    #expect(!wasmPackageSwift.contains(".package(path: \"\(swiftHTMLPackage.path)\""))
    #expect(
      !wasmPackageSwift.contains(".package(url: \"https://github.com/1amageek/swift-html.git\""))
    #expect(
      !wasmPackageSwift.contains(".package(url: \"https://github.com/swiftwasm/JavaScriptKit.git\"")
    )
    #expect(!wasmPackageSwift.contains("swift-syntax"))
    #expect(!wasmPackageSwift.contains("BridgeJSMacros"))
    #expect(
      wasmPackageSwift.contains(
        ".package(url: \"https://github.com/1amageek/swift-actor-runtime.git\", exact: \"0.6.0\")"))
    #expect(!wasmPackageSwift.contains(".package(path: \"\(swiftWebPackage.path)\""))
    #expect(!wasmPackageSwift.contains(".package(path: \"\(appPackage.path)\""))
    #expect(!wasmPackageSwift.contains("AppServerLauncher"))
    #expect(!wasmPackageSwift.contains("SwiftWebDevLauncher"))
    #expect(wasmPackageSwift.contains("let swiftHTMLTarget = Target.target("))
    #expect(wasmPackageSwift.contains("path: \"Sources/SwiftHTML\""))
    #expect(!wasmPackageSwift.contains(".product(name: \"SwiftHTML\", package: \"swift-html\")"))
    #expect(wasmPackageSwift.contains("let swiftWebActorsTarget = Target.target("))
    #expect(wasmPackageSwift.contains("path: \"Sources/SwiftWebActors\""))
    #expect(
      wasmPackageSwift.contains(
        ".product(name: \"ActorRuntime\", package: \"swift-actor-runtime\")"))
    #expect(wasmPackageSwift.contains("let swiftWebUITarget = Target.target("))
    #expect(wasmPackageSwift.contains("let swiftWebUIThemeTarget = Target.target("))
    #expect(wasmPackageSwift.contains("let cJavaScriptKitTarget = Target.target("))
    #expect(wasmPackageSwift.contains("let javaScriptKitTarget = Target.target("))
    #expect(wasmPackageSwift.contains("let swiftWebUIRuntimeTarget = Target.target("))
    #expect(wasmPackageSwift.contains("path: \"Sources/SwiftWebUITheme\""))
    #expect(wasmPackageSwift.contains("path: \"Sources/SwiftWebUIRuntime\""))
    #expect(wasmPackageSwift.contains("path: \"Sources/JavaScriptKit\""))
    #expect(wasmPackageSwift.contains("path: \"Sources/_CJavaScriptKit\""))
    #expect(wasmPackageSwift.contains("\"JavaScriptKit\""))
    #expect(
      wasmPackageSwift.contains(
        """
        let appClientTarget = Target.target(
            name: "SampleApp",
            dependencies: [
                "SwiftHTML",
                "SwiftWebActors",
                "SwiftWebUI",
                "SwiftWebUIRuntime",
            ],
        """))
    #expect(
      wasmPackageSwift.contains(
        """
        let swiftWebUIThemeTarget = Target.target(
            name: "SwiftWebUITheme",
            dependencies: [
                "SwiftHTML",
                "SwiftWebStyle",
            ],
        """))
    #expect(
      wasmPackageSwift.contains(
        """
        let swiftWebUITarget = Target.target(
            name: "SwiftWebUI",
            dependencies: [
                "SwiftHTML",
                "SwiftWebActors",
                "SwiftWebStyle",
                "SwiftWebUITheme",
            ],
        """))
    #expect(
      wasmPackageSwift.contains(
        """
        let swiftWebUIRuntimeTarget = Target.target(
            name: "SwiftWebUIRuntime",
            dependencies: [
                "SwiftHTML",
                "JavaScriptKit",
                "SwiftWebActors",
                "SwiftWebStyle",
            ],
        """))
    #expect(wasmPackageSwift.contains("--export=swiftweb_snapshot_state"))
    #expect(wasmPackageSwift.contains("--export=swiftweb_restore_state"))
    // The client hydration walk recurses the component tree; deep trees overflow
    // the default 1MB wasm stack. Pin the larger stack so it can't silently regress.
    #expect(wasmPackageSwift.contains("stack-size=16777216"))
    #expect(!wasmPackageSwift.contains("exclude: [\"README.md\"]"))

    let serverSources = generatedPackage.packageDirectory.appendingPathComponent("Sources")
    let devSources = generatedPackage.devPackageDirectory.appendingPathComponent("Sources")
    let wasmSources = generatedPackage.wasmPackageDirectory.appendingPathComponent("Sources")
    #expect(
      FileManager.default.fileExists(
        atPath: serverSources.appendingPathComponent("AppServerLauncher/ServerLauncher.swift").path
      ))
    #expect(
      !FileManager.default.fileExists(
        atPath: serverSources.appendingPathComponent("SwiftWebDevLauncher/DevLauncher.swift").path
      ))
    #expect(
      FileManager.default.fileExists(
        atPath: devSources.appendingPathComponent("SwiftWebDevLauncher/DevLauncher.swift").path
      ))
    #expect(
      FileManager.default.fileExists(
        atPath: devSources.appendingPathComponent(
          "AppDevelopmentServerLauncher/ServerLauncher.swift"
        ).path
      ))
    #expect(
      !FileManager.default.fileExists(
        atPath: serverSources.appendingPathComponent(
          "SampleAppWasmRuntime/SampleAppWasmRuntime.swift"
        ).path
      ))
    #expect(
      FileManager.default.fileExists(
        atPath: wasmSources.appendingPathComponent("SampleApp/ClientSample.swift").path
      ))
    let copiedClientSample = try String(
      contentsOf: wasmSources.appendingPathComponent("SampleApp/ClientSample.swift"),
      encoding: .utf8
    )
    #expect(!copiedClientSample.contains("@Actor"))
    #expect(copiedClientSample.contains("private var service: any SampleServiceProtocol {"))
    #expect(copiedClientSample.contains("SwiftWebActorBinding.resolve("))
    #expect(
      copiedClientSample.contains(
        "SwiftWebActorContractKey(String(reflecting: (any SampleServiceProtocol).self))"
      ))
    #expect(
      FileManager.default.fileExists(
        atPath: wasmSources.appendingPathComponent("SampleApp/ClientBadge.swift").path
      ))
    #expect(
      FileManager.default.fileExists(
        atPath: wasmSources.appendingPathComponent("SampleApp/ClientExtensionBox.swift").path
      ))
    #expect(
      FileManager.default.fileExists(
        atPath: wasmSources.appendingPathComponent("SampleApp/Services/SampleServiceProtocol.swift")
          .path
      ))
    #expect(
      FileManager.default.fileExists(
        atPath: wasmSources.appendingPathComponent(
          "SampleAppWasmRuntime/SampleAppWasmRuntime.swift"
        ).path
      ))
    let wasmEntrypoint = try String(
      contentsOf: wasmSources.appendingPathComponent(
        "SampleAppWasmRuntime/SampleAppWasmRuntime.swift"),
      encoding: .utf8
    )
    let wasmActorResolvers = try String(
      contentsOf: wasmSources.appendingPathComponent(
        "SampleApp/SwiftWebGeneratedActorResolvers.swift"),
      encoding: .utf8
    )
    let serverLauncher = try String(
      contentsOf: serverSources.appendingPathComponent("AppServerLauncher/ServerLauncher.swift"),
      encoding: .utf8
    )
    let developmentServerLauncher = try String(
      contentsOf: devSources.appendingPathComponent(
        "AppDevelopmentServerLauncher/ServerLauncher.swift"),
      encoding: .utf8
    )
    let developmentLauncher = try String(
      contentsOf: devSources.appendingPathComponent("SwiftWebDevLauncher/DevLauncher.swift"),
      encoding: .utf8
    )
    #expect(serverLauncher.contains("SWIFTWEB_WASM_SCRATCH_PATH"))
    #expect(serverLauncher.contains("import SwiftWebHTTPServerHost"))
    #expect(serverLauncher.contains("scratchDirectory: wasmScratchDirectory"))
    #expect(!serverLauncher.contains("SwiftWebDevelopmentHooksRuntime.install()"))
    #expect(developmentServerLauncher.contains("import SwiftWebHTTPServerHost"))
    #expect(developmentServerLauncher.contains("import SwiftWebDevelopmentHooks"))
    #expect(developmentServerLauncher.contains("SwiftWebDevelopmentHooksRuntime.install()"))
    #expect(developmentLauncher.contains("SWIFT_WEB_DEV_PRODUCT"))
    #expect(developmentLauncher.contains("\"app-server\""))
    #expect(!developmentLauncher.contains("\"app-server-dev\""))
    #expect(!developmentLauncher.contains("app-server-dev-dev"))
    #expect(wasmEntrypoint.contains("import SwiftWebActors"))
    #expect(
      wasmEntrypoint.contains("SwiftWebGeneratedActorResolvers.sampleAppWasmRuntime()")
    )
    #expect(wasmActorResolvers.contains("SwiftWebActorResolverRegistry(["))
    #expect(wasmActorResolvers.contains("SwiftWebActorResolver("))
    #expect(
      wasmActorResolvers.contains(
        "SwiftWebActorContractKey(String(reflecting: (any SampleServiceProtocol).self))"
      ))
    #expect(wasmActorResolvers.contains("actorContract: $SampleServiceProtocol.self"))
    #expect(wasmEntrypoint.contains("actorResolverRegistry: sampleAppWasmRuntimeActorResolvers"))
    #expect(wasmEntrypoint.contains("import SwiftWebUI"))
    #expect(wasmEntrypoint.contains("import SwiftWebUIRuntime"))
    #expect(wasmEntrypoint.contains("ClientBundleRuntimeEntrypoint"))
    #expect(wasmEntrypoint.contains("ClientComponentRegistration("))
    #expect(wasmEntrypoint.contains("ClientSample.self"))
    #expect(wasmEntrypoint.contains("ClientBadge.self"))
    #expect(wasmEntrypoint.contains("ClientExtensionBox.self"))
    #expect(wasmEntrypoint.contains("makeSwiftWebWasmRoot"))
    #expect(wasmEntrypoint.contains("ClientRuntimeBootstrapInitializable.Type"))
    #expect(wasmEntrypoint.contains("let root = try bootstrapType.init(bootstrap: request)"))
    #expect(
      FileManager.default.fileExists(
        atPath: wasmSources.appendingPathComponent("SwiftHTML/Core/HTML.swift").path
      ))
    #expect(
      FileManager.default.fileExists(
        atPath: wasmSources.appendingPathComponent("SwiftHTML/Rendering/HTMLRenderer.swift").path
      ))
    #expect(
      !FileManager.default.fileExists(
        atPath: wasmSources.appendingPathComponent("SwiftHTML/SwiftHTML.docc").path
      ))
    #expect(
      FileManager.default.fileExists(
        atPath: wasmSources.appendingPathComponent("SwiftWebActors/WebActorSystem.swift").path
      ))
    #expect(
      FileManager.default.fileExists(
        atPath: wasmSources.appendingPathComponent("SwiftWebUI/Text.swift").path
      ))
    #expect(
      FileManager.default.fileExists(
        atPath: wasmSources.appendingPathComponent("SwiftWebUITheme/ThemeToken.swift").path
      ))
    #expect(
      FileManager.default.fileExists(
        atPath: wasmSources.appendingPathComponent("SwiftWebUIRuntime/RuntimeEntrypoint.swift").path
      ))
    #expect(
      FileManager.default.fileExists(
        atPath: wasmSources.appendingPathComponent(
          "JavaScriptKit/FundamentalObjects/JSObject.swift"
        ).path
      ))
    #expect(
      FileManager.default.fileExists(
        atPath: wasmSources.appendingPathComponent("_CJavaScriptKit/include/_CJavaScriptKit.h").path
      ))
    #expect(
      !FileManager.default.fileExists(
        atPath: wasmSources.appendingPathComponent("JavaScriptKit/Macros.swift").path
      ))
    #expect(
      !FileManager.default.fileExists(
        atPath: wasmSources.appendingPathComponent("JavaScriptKit/Runtime").path
      ))
    #expect(
      !FileManager.default.fileExists(
        atPath: wasmSources.appendingPathComponent("JavaScriptKit/Documentation.docc").path
      ))
    #expect(
      !FileManager.default.fileExists(
        atPath: wasmSources.appendingPathComponent("SwiftWebUI/README.md").path
      ))
    #expect(
      !FileManager.default.fileExists(
        atPath: wasmSources.appendingPathComponent("SwiftWebUIRuntime/README.md").path
      ))
    #expect(
      !FileManager.default.fileExists(
        atPath: wasmSources.appendingPathComponent("SampleApp/App.swift").path
      ))
    #expect(
      !FileManager.default.fileExists(
        atPath: wasmSources.appendingPathComponent("SampleApp/Routes/Page.swift").path
      ))
    #expect(
      !FileManager.default.fileExists(
        atPath: wasmSources.appendingPathComponent("SampleApp/Actions/Service.swift").path
      ))
    #expect(
      !FileManager.default.fileExists(
        atPath: wasmSources.appendingPathComponent("SampleAppWasmRuntime/Runtime.swift").path
      ))
    #expect(!serverLauncher.contains("SwiftWebDevHotReload"))
    #expect(!serverLauncher.contains("__swiftWebDevReload"))
    #expect(!serverLauncher.contains("SWIFTWEB_DEV_TOKEN"))
  }

  @Test
  func materializesEmbeddedWasmRuntimePackage() throws {
    let root = FileManager.default.temporaryDirectory
      .appendingPathComponent(
        "SwiftWebEmbeddedWasmMaterializerTests-\(UUID().uuidString)", isDirectory: true)
    defer {
      do {
        try FileManager.default.removeItem(at: root)
      } catch {}
    }

    let swiftWebPackage = root.appendingPathComponent("swift-web", isDirectory: true)
    let swiftHTMLPackage = root.appendingPathComponent("swift-html", isDirectory: true)
    let appPackage = root.appendingPathComponent("SampleApp", isDirectory: true)
    try write(
      """
      // swift-tools-version: 6.3
      import PackageDescription

      let package = Package(
          name: "swift-html",
          products: [
              .library(name: "SwiftHTML", targets: ["SwiftHTML"]),
              .library(name: "SwiftHTMLClientRuntime", targets: ["SwiftHTMLClientRuntime"]),
          ],
          targets: [
              .target(name: "SwiftHTML"),
              .target(name: "SwiftHTMLClientRuntime"),
          ]
      )
      """,
      to: swiftHTMLPackage.appendingPathComponent("Package.swift")
    )
    try writeSwiftHTMLRuntimeSources(in: swiftHTMLPackage)
    try writeSwiftHTMLClientRuntimeSources(in: swiftHTMLPackage)
    try write(
      """
      // swift-tools-version: 6.3
      import PackageDescription

      let package = Package(
          name: "swift-web",
          products: [
              .library(name: "SwiftWebActors", targets: ["SwiftWebActors"]),
              .library(name: "SwiftWebStyle", targets: ["SwiftWebStyle"]),
              .library(name: "SwiftWebUI", targets: ["SwiftWebUI"]),
              .library(name: "SwiftWebUIRuntime", targets: ["SwiftWebUIRuntime"]),
              .library(name: "SwiftWebCore", targets: ["SwiftWebCore"]),
              .library(name: "SwiftWeb", targets: ["SwiftWeb"]),
              .library(name: "SwiftWebHTTPServerHost", targets: ["SwiftWebHTTPServerHost"]),
          ],
          dependencies: [
              .package(path: "\(swiftHTMLPackage.path)"),
          ],
          targets: [
              .target(name: "SwiftWebActors"),
              .target(name: "SwiftWebStyle"),
              .target(name: "SwiftWebUI"),
              .target(name: "SwiftWebUIRuntime"),
              .target(name: "SwiftWebCore"),
              .target(name: "SwiftWeb"),
              .target(name: "SwiftWebHTTPServerHost"),
          ]
      )
      """,
      to: swiftWebPackage.appendingPathComponent("Package.swift")
    )
    try writeSwiftWebStyleRuntimeSources(in: swiftWebPackage)
    try writeSwiftWebUIThemeRuntimeSources(in: swiftWebPackage)
    try write(
      "import SwiftHTML\npublic struct Text {}",
      to: swiftWebPackage.appendingPathComponent("Sources/SwiftWebUI/Components/Text.swift")
    )
    try write(
      "public struct WebActorSystem {}",
      to: swiftWebPackage.appendingPathComponent("Sources/SwiftWebRuntime/Actors/WebActorSystem.swift")
    )
    try write(
      "import SwiftHTML\npublic struct RuntimeEntrypoint {}",
      to: swiftWebPackage.appendingPathComponent(
        "Sources/SwiftWebBrowser/ClientRuntime/RuntimeEntrypoint.swift")
    )
    try writeJavaScriptKitRuntimeCheckout(in: swiftWebPackage)
    try write(
      """
      // swift-tools-version: 6.3
      import PackageDescription

      let package = Package(
          name: "SampleApp",
          products: [
              .library(name: "SampleApp", targets: ["SampleApp"]),
          ],
          dependencies: [
              .package(path: "\(swiftWebPackage.path)"),
          ],
          targets: [
              .target(name: "SampleApp"),
          ]
      )
      """,
      to: appPackage.appendingPathComponent("Package.swift")
    )
    try write(
      "public struct SampleApp {}",
      to: appPackage.appendingPathComponent("Sources/SampleApp/App.swift"))
    try write(
      "public struct ClientSample: ClientComponent { public init() {} }",
      to: appPackage.appendingPathComponent("Sources/SampleApp/ClientSample.swift")
    )

    let generatedPackage = try SwiftWebGeneratedPackageMaterializer(
      appPackageDirectory: appPackage,
      wasmRuntimeProfile: .embedded
    )
    .materialize()

    let wasmPackageSwift = try String(
      contentsOf: generatedPackage.wasmPackageDirectory.appendingPathComponent("Package.swift"),
      encoding: .utf8
    )
    let wasmSources = generatedPackage.wasmPackageDirectory.appendingPathComponent("Sources")
    let wasmEntrypoint = try String(
      contentsOf: wasmSources.appendingPathComponent(
        "SampleAppWasmRuntime/SampleAppWasmRuntime.swift"),
      encoding: .utf8
    )

    #expect(wasmPackageSwift.contains("let swiftHTMLClientRuntimeTarget = Target.target("))
    #expect(wasmPackageSwift.contains("path: \"Sources/SwiftHTMLClientRuntime\""))
    #expect(wasmPackageSwift.contains("\"SwiftHTMLClientRuntime\""))
    #expect(wasmPackageSwift.contains("\"JavaScriptKit\""))
    #expect(!wasmPackageSwift.contains("let swiftHTMLTarget = Target.target("))
    #expect(!wasmPackageSwift.contains("let swiftWebUITarget = Target.target("))
    #expect(!wasmPackageSwift.contains("let swiftWebUIRuntimeTarget = Target.target("))
    #expect(!wasmPackageSwift.contains("let appClientTarget = Target.target("))
    #expect(!wasmPackageSwift.contains("swift-actor-runtime"))
    #expect(
      FileManager.default.fileExists(
        atPath: wasmSources.appendingPathComponent(
          "SwiftHTMLClientRuntime/ClientHTMLDocument.swift"
        ).path
      ))
    #expect(
      FileManager.default.fileExists(
        atPath: wasmSources.appendingPathComponent(
          "JavaScriptKit/FundamentalObjects/JSObject.swift"
        ).path
      ))
    #expect(
      FileManager.default.fileExists(
        atPath: wasmSources.appendingPathComponent("_CJavaScriptKit/include/_CJavaScriptKit.h").path
      ))
    #expect(
      !FileManager.default.fileExists(
        atPath: wasmSources.appendingPathComponent("SwiftHTML/Core/HTML.swift").path
      ))
    #expect(
      !FileManager.default.fileExists(
        atPath: wasmSources.appendingPathComponent("SwiftWebUIRuntime/RuntimeEntrypoint.swift").path
      ))
    #expect(
      !FileManager.default.fileExists(
        atPath: wasmSources.appendingPathComponent("SampleApp/ClientSample.swift").path
      ))
    #expect(wasmEntrypoint.contains("import JavaScriptKit"))
    #expect(wasmEntrypoint.contains("import SwiftHTMLClientRuntime"))
    #expect(wasmEntrypoint.contains("SwiftWebClientRuntime"))
    #expect(wasmEntrypoint.contains("data-swiftweb-runtime"))
    #expect(!wasmEntrypoint.split(separator: "\n").contains("import SwiftHTML"))
    #expect(!wasmEntrypoint.contains("ClientBundleRuntimeEntrypoint"))
  }

  @Test
  func materializationFallsBackToSwiftWebPackageResolvedWhenAppHasNoLockfile() throws {
    let root = FileManager.default.temporaryDirectory
      .appendingPathComponent(
        "SwiftWebGeneratedPackageResolvedFallbackTests-\(UUID().uuidString)", isDirectory: true)
    defer {
      do {
        try FileManager.default.removeItem(at: root)
      } catch {}
    }

    let swiftWebPackage = root.appendingPathComponent("swift-web", isDirectory: true)
    let swiftHTMLPackage = root.appendingPathComponent("swift-html", isDirectory: true)
    let appPackage = root.appendingPathComponent("SampleApp", isDirectory: true)
    try write(
      """
      // swift-tools-version: 6.3
      import PackageDescription

      let package = Package(
          name: "swift-html",
          products: [
              .library(name: "SwiftHTML", targets: ["SwiftHTML"]),
          ],
          targets: [
              .target(name: "SwiftHTML"),
          ]
      )
      """,
      to: swiftHTMLPackage.appendingPathComponent("Package.swift")
    )
    try writeSwiftHTMLRuntimeSources(in: swiftHTMLPackage)
    try write(
      """
      // swift-tools-version: 6.3
      import PackageDescription

      let package = Package(
          name: "swift-web",
          products: [
              .library(name: "SwiftWebActors", targets: ["SwiftWebActors"]),
              .library(name: "SwiftWebStyle", targets: ["SwiftWebStyle"]),
              .library(name: "SwiftWebUI", targets: ["SwiftWebUI"]),
              .library(name: "SwiftWebUIRuntime", targets: ["SwiftWebUIRuntime"]),
              .library(name: "SwiftWebCore", targets: ["SwiftWebCore"]),
              .library(name: "SwiftWeb", targets: ["SwiftWeb"]),
              .library(name: "SwiftWebHTTPServerHost", targets: ["SwiftWebHTTPServerHost"]),
          ],
          dependencies: [
              .package(path: "\(swiftHTMLPackage.path)"),
          ],
          targets: [
              .target(name: "SwiftWebActors"),
              .target(name: "SwiftWebStyle"),
              .target(name: "SwiftWebUI"),
              .target(name: "SwiftWebUIRuntime"),
              .target(name: "SwiftWebCore"),
              .target(name: "SwiftWeb"),
              .target(name: "SwiftWebHTTPServerHost"),
          ]
      )
      """,
      to: swiftWebPackage.appendingPathComponent("Package.swift")
    )
    try writeSwiftWebStyleRuntimeSources(in: swiftWebPackage)
    try writeSwiftWebUIThemeRuntimeSources(in: swiftWebPackage)
    try write(
      """
      {
        "pins" : [
          {
            "identity" : "swift-http-server",
            "kind" : "remoteSourceControl",
            "location" : "https://github.com/swift-server/swift-http-server",
            "state" : {
              "branch" : "main",
              "revision" : "b1c4f775dfbdc74800c0f29fda79c8984a5e9073"
            }
          },
          {
            "identity" : "vapor",
            "kind" : "remoteSourceControl",
            "location" : "https://github.com/vapor/vapor.git",
            "state" : {
              "revision" : "8cfd55759c9f9e30ebdb95e30a3e80d96563f3fd"
            }
          },
          {
            "identity" : "swift-actor-runtime",
            "kind" : "remoteSourceControl",
            "location" : "https://github.com/1amageek/swift-actor-runtime.git",
            "state" : {
              "revision" : "actor-runtime-revision",
              "version" : "0.6.0"
            }
          }
        ],
        "version" : 3
      }
      """,
      to: swiftWebPackage.appendingPathComponent("Package.resolved")
    )
    try write(
      "import SwiftHTML\npublic struct Text {}",
      to: swiftWebPackage.appendingPathComponent("Sources/SwiftWebUI/Components/Text.swift")
    )
    try write(
      "public struct WebActorSystem {}",
      to: swiftWebPackage.appendingPathComponent("Sources/SwiftWebRuntime/Actors/WebActorSystem.swift")
    )
    try write(
      "import SwiftHTML\npublic struct RuntimeEntrypoint {}",
      to: swiftWebPackage.appendingPathComponent(
        "Sources/SwiftWebBrowser/ClientRuntime/RuntimeEntrypoint.swift")
    )
    try writeJavaScriptKitRuntimeCheckout(in: swiftWebPackage)
    try write(
      """
      // swift-tools-version: 6.3
      import PackageDescription

      let package = Package(
          name: "SampleApp",
          products: [
              .library(name: "SampleApp", targets: ["SampleApp"]),
          ],
          dependencies: [
              .package(path: "\(swiftWebPackage.path)"),
          ],
          targets: [
              .target(name: "SampleApp"),
          ]
      )
      """,
      to: appPackage.appendingPathComponent("Package.swift")
    )
    try write(
      "public struct SampleApp {}",
      to: appPackage.appendingPathComponent("Sources/SampleApp/App.swift"))
    try write(
      "public struct ClientSample: ClientComponent { public init() {} }",
      to: appPackage.appendingPathComponent("Sources/SampleApp/ClientSample.swift")
    )

    let generatedPackage = try SwiftWebGeneratedPackageMaterializer(
      appPackageDirectory: appPackage
    )
    .materialize()

    let serverPackageResolved = try String(
      contentsOf: generatedPackage.packageDirectory.appendingPathComponent("Package.resolved"),
      encoding: .utf8
    )
    let devPackageResolved = try String(
      contentsOf: generatedPackage.devPackageDirectory.appendingPathComponent("Package.resolved"),
      encoding: .utf8
    )
    let wasmPackageResolved = try String(
      contentsOf: generatedPackage.wasmPackageDirectory.appendingPathComponent("Package.resolved"),
      encoding: .utf8
    )
    let wasmPackageSwift = try String(
      contentsOf: generatedPackage.wasmPackageDirectory.appendingPathComponent("Package.swift"),
      encoding: .utf8
    )

    #expect(serverPackageResolved.contains("\"identity\" : \"swift-http-server\""))
    #expect(serverPackageResolved.contains("\"branch\" : \"main\""))
    #expect(devPackageResolved.contains("\"identity\" : \"swift-http-server\""))
    #expect(devPackageResolved.contains("\"branch\" : \"main\""))
    #expect(wasmPackageResolved.contains("\"identity\" : \"swift-actor-runtime\""))
    #expect(!wasmPackageResolved.contains("\"identity\" : \"swift-http-server\""))
    #expect(!wasmPackageResolved.contains("\"identity\" : \"vapor\""))
    #expect(
      wasmPackageSwift.contains(
        ".package(url: \"https://github.com/1amageek/swift-actor-runtime.git\", exact: \"0.6.0\")"))
  }

  @Test
  func serializesConcurrentMaterialization() async throws {
    let root = FileManager.default.temporaryDirectory
      .appendingPathComponent(
        "SwiftWebGeneratedPackageConcurrentTests-\(UUID().uuidString)", isDirectory: true)
    defer {
      do {
        try FileManager.default.removeItem(at: root)
      } catch {}
    }

    let swiftWebPackage = root.appendingPathComponent("swift-web", isDirectory: true)
    let swiftHTMLPackage = root.appendingPathComponent("swift-html", isDirectory: true)
    let appPackage = root.appendingPathComponent("SampleApp", isDirectory: true)
    try write(
      """
      // swift-tools-version: 6.3
      import PackageDescription

      let package = Package(
          name: "swift-html",
          products: [
              .library(name: "SwiftHTML", targets: ["SwiftHTML"]),
          ],
          targets: [
              .target(name: "SwiftHTML"),
          ]
      )
      """,
      to: swiftHTMLPackage.appendingPathComponent("Package.swift")
    )
    try writeSwiftHTMLRuntimeSources(in: swiftHTMLPackage)
    try write(
      """
      // swift-tools-version: 6.3
      import PackageDescription

      let package = Package(
          name: "swift-web",
          products: [
              .library(name: "SwiftWebActors", targets: ["SwiftWebActors"]),
              .library(name: "SwiftWebStyle", targets: ["SwiftWebStyle"]),
              .library(name: "SwiftWebUI", targets: ["SwiftWebUI"]),
              .library(name: "SwiftWebUIRuntime", targets: ["SwiftWebUIRuntime"]),
              .library(name: "SwiftWebCore", targets: ["SwiftWebCore"]),
              .library(name: "SwiftWeb", targets: ["SwiftWeb"]),
              .library(name: "SwiftWebHTTPServerHost", targets: ["SwiftWebHTTPServerHost"]),
          ],
          dependencies: [
              .package(path: "\(swiftHTMLPackage.path)"),
          ],
          targets: [
              .target(name: "SwiftWebActors"),
              .target(name: "SwiftWebStyle"),
              .target(name: "SwiftWebUI"),
              .target(name: "SwiftWebUIRuntime"),
              .target(name: "SwiftWebCore"),
              .target(name: "SwiftWeb"),
              .target(name: "SwiftWebHTTPServerHost"),
          ]
      )
      """,
      to: swiftWebPackage.appendingPathComponent("Package.swift")
    )
    try writeSwiftWebStyleRuntimeSources(in: swiftWebPackage)
    try writeSwiftWebUIThemeRuntimeSources(in: swiftWebPackage)
    try write(
      "import SwiftHTML\npublic struct Text {}",
      to: swiftWebPackage.appendingPathComponent("Sources/SwiftWebUI/Components/Text.swift")
    )
    try write(
      "public struct WebActorSystem {}",
      to: swiftWebPackage.appendingPathComponent("Sources/SwiftWebRuntime/Actors/WebActorSystem.swift")
    )
    try write(
      "import SwiftHTML\npublic struct RuntimeEntrypoint {}",
      to: swiftWebPackage.appendingPathComponent(
        "Sources/SwiftWebBrowser/ClientRuntime/RuntimeEntrypoint.swift")
    )
    try writeJavaScriptKitRuntimeCheckout(in: swiftWebPackage)
    try write(
      """
      // swift-tools-version: 6.3
      import PackageDescription

      let package = Package(
          name: "SampleApp",
          products: [
              .library(name: "SampleApp", targets: ["SampleApp"]),
          ],
          dependencies: [
              .package(path: "\(swiftWebPackage.path)"),
          ],
          targets: [
              .target(name: "SampleApp"),
          ]
      )
      """,
      to: appPackage.appendingPathComponent("Package.swift")
    )
    try write(
      "public struct SampleApp {}",
      to: appPackage.appendingPathComponent("Sources/SampleApp/App.swift"))
    try write(
      "public struct ClientSample: ClientComponent { public init() {} }",
      to: appPackage.appendingPathComponent("Sources/SampleApp/ClientSample.swift")
    )

    let errors = Mutex<[String]>([])
    await withTaskGroup(of: Void.self) { group in
      for _ in 0..<2 {
        group.addTask {
          do {
            _ = try SwiftWebGeneratedPackageMaterializer(
              appPackageDirectory: appPackage
            )
            .materialize()
          } catch {
            errors.withLock {
              $0.append(String(describing: error))
            }
          }
        }
      }
    }

    let capturedErrors = errors.withLock { $0 }
    #expect(capturedErrors.isEmpty)
    #expect(
      !FileManager.default.fileExists(
        atPath: appPackage.appendingPathComponent(".swiftweb/generated/.materialize.lock").path
      ))

    let generatedSources =
      appPackage
      .appendingPathComponent(".swiftweb/generated/wasm/Sources", isDirectory: true)
    #expect(
      FileManager.default.fileExists(
        atPath: generatedSources.appendingPathComponent("SampleApp/ClientSample.swift").path
      ))
    #expect(
      FileManager.default.fileExists(
        atPath: generatedSources.appendingPathComponent(
          "SampleAppWasmRuntime/SampleAppWasmRuntime.swift"
        ).path
      ))
    #expect(
      FileManager.default.fileExists(
        atPath: generatedSources.appendingPathComponent("SwiftHTML/Core/HTML.swift").path
      ))
    #expect(
      FileManager.default.fileExists(
        atPath: generatedSources.appendingPathComponent("SwiftWebActors/WebActorSystem.swift").path
      ))
    #expect(
      FileManager.default.fileExists(
        atPath: generatedSources.appendingPathComponent("SwiftWebUI/Text.swift").path
      ))
    #expect(
      FileManager.default.fileExists(
        atPath: generatedSources.appendingPathComponent("SwiftWebUIRuntime/RuntimeEntrypoint.swift")
          .path
      ))
    #expect(
      FileManager.default.fileExists(
        atPath: generatedSources.appendingPathComponent(
          "JavaScriptKit/FundamentalObjects/JSObject.swift"
        ).path
      ))
    #expect(
      !FileManager.default.fileExists(
        atPath: generatedSources.appendingPathComponent("JavaScriptKit/Macros.swift").path
      ))
  }

  @Test
  func materializesSplitBundlesFromClientComponentContracts() throws {
    let root = FileManager.default.temporaryDirectory
      .appendingPathComponent(
        "SwiftWebGeneratedPackageSplitBundleTests-\(UUID().uuidString)", isDirectory: true)
    defer {
      do {
        try FileManager.default.removeItem(at: root)
      } catch {}
    }

    let swiftWebPackage = root.appendingPathComponent("swift-web", isDirectory: true)
    let swiftHTMLPackage = root.appendingPathComponent("swift-html", isDirectory: true)
    let appPackage = root.appendingPathComponent("SampleApp", isDirectory: true)
    try write(
      """
      // swift-tools-version: 6.3
      import PackageDescription

      let package = Package(
          name: "swift-html",
          products: [
              .library(name: "SwiftHTML", targets: ["SwiftHTML"]),
          ],
          targets: [
              .target(name: "SwiftHTML"),
          ]
      )
      """,
      to: swiftHTMLPackage.appendingPathComponent("Package.swift")
    )
    try writeSwiftHTMLRuntimeSources(in: swiftHTMLPackage)
    try write(
      """
      // swift-tools-version: 6.3
      import PackageDescription

      let package = Package(
          name: "swift-web",
          products: [
              .library(name: "SwiftWebActors", targets: ["SwiftWebActors"]),
              .library(name: "SwiftWebStyle", targets: ["SwiftWebStyle"]),
              .library(name: "SwiftWebUI", targets: ["SwiftWebUI"]),
              .library(name: "SwiftWebUIRuntime", targets: ["SwiftWebUIRuntime"]),
              .library(name: "SwiftWebCore", targets: ["SwiftWebCore"]),
              .library(name: "SwiftWeb", targets: ["SwiftWeb"]),
              .library(name: "SwiftWebHTTPServerHost", targets: ["SwiftWebHTTPServerHost"]),
          ],
          dependencies: [
              .package(path: "\(swiftHTMLPackage.path)"),
          ],
          targets: [
              .target(name: "SwiftWebActors"),
              .target(name: "SwiftWebStyle"),
              .target(name: "SwiftWebUI"),
              .target(name: "SwiftWebUIRuntime"),
              .target(name: "SwiftWebCore"),
              .target(name: "SwiftWeb"),
              .target(name: "SwiftWebHTTPServerHost"),
          ]
      )
      """,
      to: swiftWebPackage.appendingPathComponent("Package.swift")
    )
    try writeSwiftWebStyleRuntimeSources(in: swiftWebPackage)
    try writeSwiftWebUIThemeRuntimeSources(in: swiftWebPackage)
    try write(
      "import SwiftHTML\npublic struct Text {}",
      to: swiftWebPackage.appendingPathComponent("Sources/SwiftWebUI/Components/Text.swift")
    )
    try write(
      "public struct WebActorSystem {}",
      to: swiftWebPackage.appendingPathComponent("Sources/SwiftWebRuntime/Actors/WebActorSystem.swift")
    )
    try write(
      "import SwiftHTML\npublic struct RuntimeEntrypoint {}",
      to: swiftWebPackage.appendingPathComponent(
        "Sources/SwiftWebBrowser/ClientRuntime/RuntimeEntrypoint.swift")
    )
    try writeJavaScriptKitRuntimeCheckout(in: swiftWebPackage)
    try write(
      """
      // swift-tools-version: 6.3
      import PackageDescription

      let package = Package(
          name: "SampleApp",
          products: [
              .library(name: "SampleApp", targets: ["SampleApp"]),
          ],
          dependencies: [
              .package(path: "\(swiftWebPackage.path)"),
          ],
          targets: [
              .target(name: "SampleApp"),
          ]
      )
      """,
      to: appPackage.appendingPathComponent("Package.swift")
    )
    try write(
      "public struct SampleApp {}",
      to: appPackage.appendingPathComponent("Sources/SampleApp/App.swift"))
    try write(
      "public struct ClientShell: ClientComponent { public init() {} }",
      to: appPackage.appendingPathComponent("Sources/SampleApp/ClientShell.swift")
    )
    try write(
      """
      public struct ClientChart: ClientComponent {
          public static let loadPolicy: LoadPolicy = .visible
          public init() {}
      }
      """,
      to: appPackage.appendingPathComponent("Sources/SampleApp/ClientChart.swift")
    )
    try write(
      """
      public struct ClientEditor: ClientComponent {
          public static let loadPolicy: LoadPolicy = .interaction
          public static let bundle: BundlePolicy = .named("editing")
          public init() {}
      }
      """,
      to: appPackage.appendingPathComponent("Sources/SampleApp/ClientEditor.swift")
    )

    let generatedPackage = try SwiftWebGeneratedPackageMaterializer(
      appPackageDirectory: appPackage,
      wasmSplitBuildStrategy: .resolvedBundles
    )
    .materialize()

    #expect(generatedPackage.wasmProductNames.contains("sample-app-wasm-runtime"))
    #expect(generatedPackage.wasmProductNames.contains("named-editing-wasm-runtime"))
    #expect(generatedPackage.wasmProductNames.count == 3)

    let wasmPackageSwift = try String(
      contentsOf: generatedPackage.wasmPackageDirectory.appendingPathComponent("Package.swift"),
      encoding: .utf8
    )
    #expect(
      wasmPackageSwift.contains(
        ".executable(name: \"sample-app-wasm-runtime\", targets: [\"SampleAppWasmRuntime\"])"))
    #expect(
      wasmPackageSwift.contains(
        ".executable(name: \"named-editing-wasm-runtime\", targets: [\"NamedEditingWasmRuntime\"])")
    )

    let serverLauncher = try String(
      contentsOf: generatedPackage.packageDirectory
        .appendingPathComponent("Sources/AppServerLauncher/ServerLauncher.swift"),
      encoding: .utf8
    )
    #expect(serverLauncher.contains("id: \"named-editing\""))
    #expect(serverLauncher.contains("componentTypeNames: [\"ClientEditor\"]"))
    #expect(serverLauncher.contains("id: \"component-"))
    #expect(serverLauncher.contains("componentTypeNames: [\"ClientChart\"]"))

    let wasmSources = generatedPackage.wasmPackageDirectory.appendingPathComponent("Sources")
    let mainEntrypoint = try String(
      contentsOf: wasmSources.appendingPathComponent(
        "SampleAppWasmRuntime/SampleAppWasmRuntime.swift"),
      encoding: .utf8
    )
    let namedEntrypoint = try String(
      contentsOf: wasmSources.appendingPathComponent(
        "NamedEditingWasmRuntime/NamedEditingWasmRuntime.swift"),
      encoding: .utf8
    )
    #expect(mainEntrypoint.contains("ClientShell.self"))
    #expect(!mainEntrypoint.contains("ClientChart.self"))
    #expect(!mainEntrypoint.contains("ClientEditor.self"))
    #expect(namedEntrypoint.contains("ClientEditor.self"))

    let splitEntrypoints = try FileManager.default.contentsOfDirectory(
      at: wasmSources,
      includingPropertiesForKeys: [.isDirectoryKey]
    )
    .filter { $0.lastPathComponent.hasPrefix("Component") }
    .map { directory in
      try String(
        contentsOf: directory.appendingPathComponent("\(directory.lastPathComponent).swift"),
        encoding: .utf8
      )
    }
    #expect(splitEntrypoints.count == 1)
    #expect(splitEntrypoints.first?.contains("ClientChart.self") == true)
  }

  @Test
  func coalescesPolicyBundlesWhenStaticLinkFallbackIsSelected() throws {
    let root = FileManager.default.temporaryDirectory
      .appendingPathComponent(
        "SwiftWebGeneratedPackageCoalescedTests-\(UUID().uuidString)", isDirectory: true)
    defer {
      do {
        try FileManager.default.removeItem(at: root)
      } catch {}
    }

    let swiftWebPackage = root.appendingPathComponent("swift-web", isDirectory: true)
    let swiftHTMLPackage = root.appendingPathComponent("swift-html", isDirectory: true)
    let appPackage = root.appendingPathComponent("SampleApp", isDirectory: true)
    try write(
      """
      // swift-tools-version: 6.3
      import PackageDescription

      let package = Package(
          name: "swift-html",
          products: [
              .library(name: "SwiftHTML", targets: ["SwiftHTML"]),
          ],
          targets: [
              .target(name: "SwiftHTML"),
          ]
      )
      """,
      to: swiftHTMLPackage.appendingPathComponent("Package.swift")
    )
    try writeSwiftHTMLRuntimeSources(in: swiftHTMLPackage)
    try write(
      """
      // swift-tools-version: 6.3
      import PackageDescription

      let package = Package(
          name: "swift-web",
          products: [
              .library(name: "SwiftWebActors", targets: ["SwiftWebActors"]),
              .library(name: "SwiftWebStyle", targets: ["SwiftWebStyle"]),
              .library(name: "SwiftWebUI", targets: ["SwiftWebUI"]),
              .library(name: "SwiftWebUIRuntime", targets: ["SwiftWebUIRuntime"]),
              .library(name: "SwiftWebCore", targets: ["SwiftWebCore"]),
              .library(name: "SwiftWeb", targets: ["SwiftWeb"]),
              .library(name: "SwiftWebHTTPServerHost", targets: ["SwiftWebHTTPServerHost"]),
          ],
          dependencies: [
              .package(path: "\(swiftHTMLPackage.path)"),
          ],
          targets: [
              .target(name: "SwiftWebActors"),
              .target(name: "SwiftWebStyle"),
              .target(name: "SwiftWebUI"),
              .target(name: "SwiftWebUIRuntime"),
              .target(name: "SwiftWebCore"),
              .target(name: "SwiftWeb"),
              .target(name: "SwiftWebHTTPServerHost"),
          ]
      )
      """,
      to: swiftWebPackage.appendingPathComponent("Package.swift")
    )
    try writeSwiftWebStyleRuntimeSources(in: swiftWebPackage)
    try writeSwiftWebUIThemeRuntimeSources(in: swiftWebPackage)
    try write(
      "import SwiftHTML\npublic struct Text {}",
      to: swiftWebPackage.appendingPathComponent("Sources/SwiftWebUI/Components/Text.swift")
    )
    try write(
      "public struct WebActorSystem {}",
      to: swiftWebPackage.appendingPathComponent("Sources/SwiftWebRuntime/Actors/WebActorSystem.swift")
    )
    try write(
      "import SwiftHTML\npublic struct RuntimeEntrypoint {}",
      to: swiftWebPackage.appendingPathComponent(
        "Sources/SwiftWebBrowser/ClientRuntime/RuntimeEntrypoint.swift")
    )
    try writeJavaScriptKitRuntimeCheckout(in: swiftWebPackage)
    try write(
      """
      // swift-tools-version: 6.3
      import PackageDescription

      let package = Package(
          name: "SampleApp",
          products: [
              .library(name: "SampleApp", targets: ["SampleApp"]),
          ],
          dependencies: [
              .package(path: "\(swiftWebPackage.path)"),
          ],
          targets: [
              .target(name: "SampleApp"),
          ]
      )
      """,
      to: appPackage.appendingPathComponent("Package.swift")
    )
    try write(
      "public struct SampleApp {}",
      to: appPackage.appendingPathComponent("Sources/SampleApp/App.swift"))
    try write(
      "public struct ClientShell: ClientComponent { public init() {} }",
      to: appPackage.appendingPathComponent("Sources/SampleApp/ClientShell.swift")
    )
    try write(
      """
      public struct ClientChart: ClientComponent {
          public static let loadPolicy: LoadPolicy = .visible
          public init() {}
      }
      """,
      to: appPackage.appendingPathComponent("Sources/SampleApp/ClientChart.swift")
    )
    try write(
      """
      public struct ClientEditor: ClientComponent {
          public static let loadPolicy: LoadPolicy = .interaction
          public static let bundle: BundlePolicy = .named("editing")
          public init() {}
      }
      """,
      to: appPackage.appendingPathComponent("Sources/SampleApp/ClientEditor.swift")
    )
    try write(
      """
      public struct ClientInspector: ClientComponent {
          public static let loadPolicy: LoadPolicy = .manual
          public static let bundle: BundlePolicy = .shared("tools")
          public init() {}
      }
      """,
      to: appPackage.appendingPathComponent("Sources/SampleApp/ClientInspector.swift")
    )
    try write(
      """
      public struct ClientTile: ClientComponent {
          public init() {}
      }

      public struct ClientUsageSamples {
          public init() {}

          public func render() {
              _ = ClientTile().loadPolicy(.visible)
              _ = ClientTile().loadPolicy(.visible).bundle(.shared("left"))
              _ = ClientTile().loadPolicy(.visible).bundle(.shared("right"))
              _ = ClientTile().loadPolicy(.manual).bundle(.shared("tools"))
          }
      }
      """,
      to: appPackage.appendingPathComponent("Sources/SampleApp/ClientUsageSamples.swift")
    )

    let generatedPackage = try SwiftWebGeneratedPackageMaterializer(
      appPackageDirectory: appPackage,
      wasmSplitBuildStrategy: .coalescedPolicyBundles
    )
    .materialize()

    #expect(
      generatedPackage.wasmProductNames == [
        "sample-app-wasm-runtime",
        "sample-app-visible-wasm-runtime",
        "sample-app-interaction-wasm-runtime",
        "sample-app-manual-wasm-runtime",
      ])
    #expect(generatedPackage.wasmRuntimes.count == 4)
    #expect(generatedPackage.wasmRuntimes[0].linkMode == .standalone)
    #expect(
      generatedPackage.wasmRuntimes.dropFirst().allSatisfy {
        $0.linkMode == .coalescedStaticFallback
      })
    let visibleRuntime = try #require(
      generatedPackage.wasmRuntimes.first {
        $0.productName == "sample-app-visible-wasm-runtime"
      })
    #expect(visibleRuntime.componentTypeNames.filter { $0 == "ClientTile" }.count == 1)
    #expect(
      generatedPackage.wasmRuntimes.flatMap(\.componentTypeNames).sorted() == [
        "ClientChart",
        "ClientEditor",
        "ClientInspector",
        "ClientShell",
        "ClientTile",
        "ClientTile",
      ])

    let wasmPackageSwift = try String(
      contentsOf: generatedPackage.wasmPackageDirectory.appendingPathComponent("Package.swift"),
      encoding: .utf8
    )
    #expect(
      wasmPackageSwift.contains(
        ".executable(name: \"sample-app-visible-wasm-runtime\", targets: [\"SampleAppVisibleWasmRuntime\"])"
      ))
    #expect(
      wasmPackageSwift.contains(
        ".executable(name: \"sample-app-interaction-wasm-runtime\", targets: [\"SampleAppInteractionWasmRuntime\"])"
      ))
    #expect(
      wasmPackageSwift.contains(
        ".executable(name: \"sample-app-manual-wasm-runtime\", targets: [\"SampleAppManualWasmRuntime\"])"
      ))
    #expect(!wasmPackageSwift.contains("named-editing-wasm-runtime"))
    #expect(!wasmPackageSwift.contains("shared-tools-wasm-runtime"))

    let serverLauncher = try String(
      contentsOf: generatedPackage.packageDirectory
        .appendingPathComponent("Sources/AppServerLauncher/ServerLauncher.swift"),
      encoding: .utf8
    )
    #expect(serverLauncher.contains("id: \"named-editing\""))
    #expect(serverLauncher.contains("id: \"shared-tools\""))
    #expect(serverLauncher.contains("id: \"shared-left\""))
    #expect(serverLauncher.contains("id: \"shared-right\""))
    #expect(serverLauncher.contains("id: \"component-"))
    #expect(
      serverLauncher.contains(
        "componentTypeNames: [\"ClientEditor\"]"
      ))
    #expect(
      serverLauncher.contains(
        "componentTypeNames: [\"ClientInspector\", \"ClientTile\"]"
      ))
    #expect(
      serverLauncher.contains(
        "componentTypeNames: [\"ClientChart\"]"
      ))
    #expect(serverLauncher.contains("assetPath: \"/assets/sample-app-visible-wasm-runtime.wasm\""))
    #expect(
      serverLauncher.contains("assetPath: \"/assets/sample-app-interaction-wasm-runtime.wasm\""))
    #expect(serverLauncher.contains("assetPath: \"/assets/sample-app-manual-wasm-runtime.wasm\""))
    #expect(serverLauncher.contains("artifactName: \"sample-app-visible-wasm-runtime\""))
    #expect(serverLauncher.contains("artifactName: \"sample-app-interaction-wasm-runtime\""))
    #expect(serverLauncher.contains("artifactName: \"sample-app-manual-wasm-runtime\""))

    let visibleEntrypoint = try String(
      contentsOf: generatedPackage.wasmPackageDirectory
        .appendingPathComponent(
          "Sources/SampleAppVisibleWasmRuntime/SampleAppVisibleWasmRuntime.swift"
        ),
      encoding: .utf8
    )
    let interactionEntrypoint = try String(
      contentsOf: generatedPackage.wasmPackageDirectory
        .appendingPathComponent(
          "Sources/SampleAppInteractionWasmRuntime/SampleAppInteractionWasmRuntime.swift"
        ),
      encoding: .utf8
    )
    let manualEntrypoint = try String(
      contentsOf: generatedPackage.wasmPackageDirectory
        .appendingPathComponent(
          "Sources/SampleAppManualWasmRuntime/SampleAppManualWasmRuntime.swift"
        ),
      encoding: .utf8
    )
    #expect(visibleEntrypoint.contains("ClientChart.self"))
    #expect(visibleEntrypoint.contains("ClientTile.self"))
    #expect(!visibleEntrypoint.contains("ClientEditor.self"))
    #expect(interactionEntrypoint.contains("ClientEditor.self"))
    #expect(!interactionEntrypoint.contains("ClientChart.self"))
    #expect(manualEntrypoint.contains("ClientInspector.self"))
    #expect(manualEntrypoint.contains("ClientTile.self"))
    #expect(!manualEntrypoint.contains("ClientShell.self"))
  }

  @Test
  func repeatedMaterializationPreservesUnchangedGeneratedFiles() throws {
    let root = FileManager.default.temporaryDirectory
      .appendingPathComponent(
        "SwiftWebGeneratedPackageIncrementalTests-\(UUID().uuidString)", isDirectory: true)
    defer {
      do {
        try FileManager.default.removeItem(at: root)
      } catch {}
    }

    let swiftWebPackage = root.appendingPathComponent("swift-web", isDirectory: true)
    let swiftHTMLPackage = root.appendingPathComponent("swift-html", isDirectory: true)
    let appPackage = root.appendingPathComponent("SampleApp", isDirectory: true)
    try write(
      """
      // swift-tools-version: 6.3
      import PackageDescription

      let package = Package(
          name: "swift-html",
          products: [
              .library(name: "SwiftHTML", targets: ["SwiftHTML"]),
          ],
          targets: [
              .target(name: "SwiftHTML"),
          ]
      )
      """,
      to: swiftHTMLPackage.appendingPathComponent("Package.swift")
    )
    try writeSwiftHTMLRuntimeSources(in: swiftHTMLPackage)
    try write(
      """
      // swift-tools-version: 6.3
      import PackageDescription

      let package = Package(
          name: "swift-web",
          products: [
              .library(name: "SwiftWebActors", targets: ["SwiftWebActors"]),
              .library(name: "SwiftWebStyle", targets: ["SwiftWebStyle"]),
              .library(name: "SwiftWebUI", targets: ["SwiftWebUI"]),
              .library(name: "SwiftWebUIRuntime", targets: ["SwiftWebUIRuntime"]),
              .library(name: "SwiftWebCore", targets: ["SwiftWebCore"]),
              .library(name: "SwiftWeb", targets: ["SwiftWeb"]),
              .library(name: "SwiftWebHTTPServerHost", targets: ["SwiftWebHTTPServerHost"]),
          ],
          dependencies: [
              .package(path: "\(swiftHTMLPackage.path)"),
          ],
          targets: [
              .target(name: "SwiftWebActors"),
              .target(name: "SwiftWebStyle"),
              .target(name: "SwiftWebUI"),
              .target(name: "SwiftWebUIRuntime"),
              .target(name: "SwiftWebCore"),
              .target(name: "SwiftWeb"),
              .target(name: "SwiftWebHTTPServerHost"),
          ]
      )
      """,
      to: swiftWebPackage.appendingPathComponent("Package.swift")
    )
    try writeSwiftWebStyleRuntimeSources(in: swiftWebPackage)
    try writeSwiftWebUIThemeRuntimeSources(in: swiftWebPackage)
    try write(
      "import SwiftHTML\npublic struct Text {}",
      to: swiftWebPackage.appendingPathComponent("Sources/SwiftWebUI/Components/Text.swift")
    )
    try write(
      "public struct WebActorSystem {}",
      to: swiftWebPackage.appendingPathComponent("Sources/SwiftWebRuntime/Actors/WebActorSystem.swift")
    )
    try write(
      "import SwiftHTML\npublic struct RuntimeEntrypoint {}",
      to: swiftWebPackage.appendingPathComponent(
        "Sources/SwiftWebBrowser/ClientRuntime/RuntimeEntrypoint.swift")
    )
    try writeJavaScriptKitRuntimeCheckout(in: swiftWebPackage)
    try write(
      """
      // swift-tools-version: 6.3
      import PackageDescription

      let package = Package(
          name: "SampleApp",
          products: [
              .library(name: "SampleApp", targets: ["SampleApp"]),
          ],
          dependencies: [
              .package(path: "\(swiftWebPackage.path)"),
          ],
          targets: [
              .target(name: "SampleApp"),
          ]
      )
      """,
      to: appPackage.appendingPathComponent("Package.swift")
    )
    try write(
      "public struct SampleApp {}",
      to: appPackage.appendingPathComponent("Sources/SampleApp/App.swift"))
    try write(
      "public struct ClientSample: ClientComponent { public init() {} }",
      to: appPackage.appendingPathComponent("Sources/SampleApp/ClientSample.swift")
    )

    let materializer = SwiftWebGeneratedPackageMaterializer(appPackageDirectory: appPackage)
    let generatedPackage = try materializer.materialize()
    let packageSwift = generatedPackage.wasmPackageDirectory.appendingPathComponent("Package.swift")
    let wasmEntrypoint = generatedPackage.wasmPackageDirectory
      .appendingPathComponent("Sources/SampleAppWasmRuntime/SampleAppWasmRuntime.swift")
    let copiedClientSource = generatedPackage.wasmPackageDirectory
      .appendingPathComponent("Sources/SampleApp/ClientSample.swift")
    let initialPackageDate = try #require(
      packageSwift.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate)
    let initialEntrypointDate = try #require(
      wasmEntrypoint.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate)
    let initialCopiedSourceDate = try #require(
      copiedClientSource.resourceValues(forKeys: [.contentModificationDateKey])
        .contentModificationDate)

    Thread.sleep(forTimeInterval: 1.1)
    _ = try materializer.materialize()

    let nextPackageDate = try #require(
      packageSwift.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate)
    let nextEntrypointDate = try #require(
      wasmEntrypoint.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate)
    let nextCopiedSourceDate = try #require(
      copiedClientSource.resourceValues(forKeys: [.contentModificationDateKey])
        .contentModificationDate)

    #expect(nextPackageDate == initialPackageDate)
    #expect(nextEntrypointDate == initialEntrypointDate)
    #expect(nextCopiedSourceDate == initialCopiedSourceDate)
  }

  private func write(_ contents: String, to url: URL) throws {
    try FileManager.default.createDirectory(
      at: url.deletingLastPathComponent(),
      withIntermediateDirectories: true
    )
    try contents.write(to: url, atomically: true, encoding: .utf8)
  }

  private func writeJavaScriptKitRuntimeCheckout(in swiftWebPackage: URL) throws {
    let sourceRoot =
      swiftWebPackage
      .appendingPathComponent(".build/checkouts/JavaScriptKit/Sources", isDirectory: true)
    try write(
      "public final class JSObject {}",
      to: sourceRoot.appendingPathComponent("JavaScriptKit/FundamentalObjects/JSObject.swift")
    )
    try write(
      "public macro JS() = #externalMacro(module: \"BridgeJSMacros\", type: \"JSMacro\")",
      to: sourceRoot.appendingPathComponent("JavaScriptKit/Macros.swift")
    )
    try write(
      "runtime",
      to: sourceRoot.appendingPathComponent("JavaScriptKit/Runtime/runtime.mjs")
    )
    try write(
      "# Documentation",
      to: sourceRoot.appendingPathComponent("JavaScriptKit/Documentation.docc/Documentation.md")
    )
    try write(
      "#pragma once",
      to: sourceRoot.appendingPathComponent("_CJavaScriptKit/include/_CJavaScriptKit.h")
    )
  }

  private func writeSwiftHTMLRuntimeSources(in swiftHTMLPackage: URL) throws {
    let sourceRoot = swiftHTMLPackage.appendingPathComponent("Sources/SwiftHTML", isDirectory: true)
    try write(
      "public protocol HTML: Sendable {}",
      to: sourceRoot.appendingPathComponent("Core/HTML.swift")
    )
    try write(
      "public struct HTMLRenderer {}",
      to: sourceRoot.appendingPathComponent("Rendering/HTMLRenderer.swift")
    )
    try write(
      "# Documentation",
      to: sourceRoot.appendingPathComponent("SwiftHTML.docc/SwiftHTML.md")
    )
  }

  private func writeSwiftWebStyleRuntimeSources(in swiftWebPackage: URL) throws {
    try write(
      "import SwiftHTML\npublic struct StyleRegistry { public init() {} }",
      to: swiftWebPackage.appendingPathComponent("Sources/SwiftWebUI/Style/StyleRegistry.swift")
    )
  }

  private func writeSwiftWebUIThemeRuntimeSources(in swiftWebPackage: URL) throws {
    try write(
      "import SwiftHTML\nimport SwiftWebStyle\npublic struct ThemeToken { public init() {} }",
      to: swiftWebPackage.appendingPathComponent("Sources/SwiftWebUI/Theme/ThemeToken.swift")
    )
  }

  private func writeSwiftHTMLClientRuntimeSources(in swiftHTMLPackage: URL) throws {
    let sourceRoot = swiftHTMLPackage.appendingPathComponent(
      "Sources/SwiftHTMLClientRuntime",
      isDirectory: true
    )
    try write(
      "public protocol ClientDOMHost {}",
      to: sourceRoot.appendingPathComponent("ClientDOMHost.swift")
    )
    try write(
      "public struct ClientHTMLDocument {}",
      to: sourceRoot.appendingPathComponent("ClientHTMLDocument.swift")
    )
  }
}
