import Foundation

struct DevPackageFormat: GeneratedPackageFormat {
  let packageKind = GeneratedPackageKind.dev

  func files(context: GeneratedPackageRenderContext) throws -> [GeneratedFile] {
    [
      GeneratedFile(
        packageKind: packageKind,
        relativePath: "Sources/SwiftWebDevLauncher/DevLauncher.swift",
        contents: devLauncherSwift(context: context)
      ),
      GeneratedFile(
        packageKind: packageKind,
        relativePath: "Sources/AppDevelopmentServerLauncher/ServerLauncher.swift",
        contents: ServerPackageFormat.serverLauncherSwift(
          context: context,
          installsDevelopmentHooks: true
        )
      ),
      GeneratedFile(
        packageKind: packageKind,
        relativePath: "Package.swift",
        contents: packageSwift(context: context)
      ),
    ]
  }

  private func devLauncherSwift(context: GeneratedPackageRenderContext) -> String {
    """
    import \(context.appProductName)
    import Foundation
    import SwiftWebDevelopment

    @main
    struct SwiftWebDevLauncher {
        static func main() async throws {
            SwiftWebDevConsoleLogging.bootstrap()

            let environment = ProcessInfo.processInfo.environment
            let appPackagePath = environment["SWIFT_WEB_APP_PACKAGE_PATH"] ?? "\(GeneratedPackageNameFormatter.swiftStringLiteral(context.layout.appPackageDirectory.path))"
            let product = environment["SWIFT_WEB_DEV_PRODUCT"] ?? "\(GeneratedPackageNameFormatter.swiftStringLiteral(context.serverProductName))"
            let host = environment["SWIFT_WEB_DEV_HOST"] ?? "127.0.0.1"
            let port = try integerEnvironment("SWIFT_WEB_DEV_PORT", in: environment, defaultValue: 3000)

            let configuration = SwiftWebDevRuntimeConfiguration(
                packageDirectory: URL(fileURLWithPath: appPackagePath),
                product: product,
                host: host,
                port: port
            )
            try await SwiftWebDevRuntime(configuration: configuration).run()
        }

        private static func integerEnvironment(
            _ key: String,
            in environment: [String: String],
            defaultValue: Int
        ) throws -> Int {
            guard let rawValue = environment[key] else {
                return defaultValue
            }
            guard let value = Int(rawValue) else {
                throw SwiftWebDevLauncherError.invalidIntegerEnvironment(key: key, value: rawValue)
            }
            return value
        }
    }

    enum SwiftWebDevLauncherError: Error, CustomStringConvertible {
        case invalidIntegerEnvironment(key: String, value: String)

        var description: String {
            switch self {
            case .invalidIntegerEnvironment(let key, let value):
                return "\\(key) must be an integer, but got \\(value)"
            }
        }
    }
    """
  }

  private func packageSwift(context: GeneratedPackageRenderContext) -> String {
    let appDependencyPath = GeneratedPackageNameFormatter.relativePath(
      from: context.layout.devPackageDirectory,
      to: context.layout.appPackageDirectory
    )
    let swiftWebDependencyPath = GeneratedPackageNameFormatter.relativePath(
      from: context.layout.devPackageDirectory,
      to: context.swiftWebPackageDirectory
    )
    return """
      // swift-tools-version: 6.3

      import PackageDescription

      let swiftSettings: [SwiftSetting] = [
          .enableUpcomingFeature("ApproachableConcurrency"),
      ]

      let swiftWebDevLauncherTarget = Target.executableTarget(
          name: "SwiftWebDevLauncher",
          dependencies: [
              .product(name: "\(context.appProductName)", package: "\(context.appPackageDependencyName)"),
              .product(name: "SwiftWebDevelopment", package: "swift-web"),
          ],
          path: "Sources/SwiftWebDevLauncher",
          swiftSettings: swiftSettings
      )

      let appDevelopmentServerTarget = Target.executableTarget(
          name: "AppDevelopmentServerLauncher",
          dependencies: [
              .product(name: "\(context.appProductName)", package: "\(context.appPackageDependencyName)"),
              .product(name: "SwiftWebHTTPServerHost", package: "swift-web"),
              .product(name: "SwiftWebDevelopmentHooks", package: "swift-web"),
          ],
          path: "Sources/AppDevelopmentServerLauncher",
          swiftSettings: swiftSettings
      )

      let package = Package(
          name: "\(context.appPackageName)DevGenerated",
          platforms: [
              .macOS("26.2"),
          ],
          products: [
              .executable(name: "\(context.devProductName)", targets: ["SwiftWebDevLauncher"]),
              .executable(name: "\(context.developmentServerProductName)", targets: ["AppDevelopmentServerLauncher"]),
          ],
          dependencies: [
              .package(path: "\(GeneratedPackageNameFormatter.swiftStringLiteral(appDependencyPath))"),
              .package(path: "\(GeneratedPackageNameFormatter.swiftStringLiteral(swiftWebDependencyPath))"),
          ],
          targets: [
              swiftWebDevLauncherTarget,
              appDevelopmentServerTarget,
          ],
          swiftLanguageModes: [.v6]
      )
      """
  }
}
