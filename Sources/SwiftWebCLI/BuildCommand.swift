import Foundation
import SwiftWebCore
import SwiftWebDevelopment

struct BuildCommand {
  let packageDirectory: URL
  let scratchDirectory: URL?
  let product: String?
  let buildsWasmRuntime: Bool
  let swiftSDK: String?
  let configuration: String?
  let wasmRuntimeProfile: SwiftWebWasmRuntimeProfile

  static func parse(_ parser: ArgumentParser) throws -> BuildCommand {
    var parser = parser
    var packageDirectory = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
    var scratchDirectory: URL?
    var product: String?
    var buildsWasmRuntime = false
    var swiftSDK: String?
    var configuration: String?
    var wasmRuntimeProfile = SwiftWebWasmRuntimeProfile.defaultValue()

    while let option = parser.next() {
      switch option {
      case "--package-path":
        packageDirectory = URL(fileURLWithPath: try parser.requireValue(after: option))
      case "--scratch-path":
        scratchDirectory = URL(fileURLWithPath: try parser.requireValue(after: option))
      case "--product":
        product = try parser.requireValue(after: option)
      case "--wasm":
        buildsWasmRuntime = true
      case "--runtime", "--wasm-runtime":
        let rawValue = try parser.requireValue(after: option)
        guard rawValue == SwiftWebWasmRuntimeProfile.standard.rawValue else {
          throw CLIError(
            message:
              "unsupported WASM runtime profile: \(rawValue). SwiftWeb supports the standard WASM profile only.",
            exitCode: 64
          )
        }
        wasmRuntimeProfile = .standard
      case "--swift-sdk":
        swiftSDK = try parser.requireValue(after: option)
      case "-c", "--configuration":
        configuration = try parser.requireValue(after: option)
      default:
        throw CLIError(message: "unknown option: \(option)", exitCode: 64)
      }
    }

    return BuildCommand(
      packageDirectory: packageDirectory.standardizedFileURL,
      scratchDirectory: scratchDirectory?.standardizedFileURL,
      product: product,
      buildsWasmRuntime: buildsWasmRuntime,
      swiftSDK: swiftSDK,
      configuration: configuration,
      wasmRuntimeProfile: wasmRuntimeProfile
    )
  }

  func run() throws {
    try validateSupportedWasmRuntimeProfile()
    let resolvedSwiftSDK = try resolvedSwiftSDKName()
    let wasmToolchain = try resolvedWasmToolchain(swiftSDK: resolvedSwiftSDK)
    let generatedPackage = try SwiftWebGeneratedPackageMaterializer(
      appPackageDirectory: packageDirectory,
      serverProductName: product ?? "app-server",
      wasmRuntimeProfile: wasmRuntimeProfile
    )
    .materialize()
    let productName = try resolvedProductName(from: generatedPackage)
    let wasmRuntime = try resolvedWasmRuntime(productName: productName, from: generatedPackage)
    let buildPackageDirectory =
      buildsWasmRuntime
      ? generatedPackage.wasmPackageDirectory
      : generatedPackage.packageDirectory
    let resolvedScratchDirectory =
      scratchDirectory ?? defaultScratchDirectory(from: generatedPackage)
    let resolvedConfiguration = configuration ?? (buildsWasmRuntime ? "release" : nil)
    var arguments = [
      "build",
      "--package-path",
      buildPackageDirectory.path,
      "--product",
      productName,
    ]

    if let resolvedScratchDirectory {
      arguments.append("--scratch-path")
      arguments.append(resolvedScratchDirectory.path)
    }
    if let resolvedSwiftSDK {
      arguments.append("--swift-sdk")
      arguments.append(resolvedSwiftSDK)
    }
    if let resolvedConfiguration {
      arguments.append("-c")
      arguments.append(resolvedConfiguration)
    }

    var environment = ProcessInfo.processInfo.environment
    if buildsWasmRuntime {
      environment["SWIFTWEB_WASM_BUILD"] = "1"
      environment["SWIFTWEB_CORE_ONLY"] = "1"
      environment["SWIFTWEB_WASM_RUNTIME_PROFILE"] = wasmRuntimeProfile.rawValue
      if let wasmToolchain {
        environment = wasmToolchain.applying(to: environment)
      }
    }

    let invocation = wasmToolchain.map(SwiftBuildInvocation.wasm(toolchain:)) ?? .host()
    try runProcess(
      arguments: invocation.arguments(for: arguments),
      executableURL: invocation.executableURL,
      environment: environment
    )
    if let wasmRuntime {
      try processWasmArtifact(
        runtime: wasmRuntime,
        scratchDirectory: resolvedScratchDirectory,
        configuration: resolvedConfiguration ?? "debug"
      )
    }
  }

  private func validateSupportedWasmRuntimeProfile() throws {
    guard !buildsWasmRuntime || wasmRuntimeProfile == .standard else {
      throw CLIError(
        message:
          "unsupported WASM runtime profile: \(wasmRuntimeProfile.rawValue). SwiftWeb supports the standard WASM profile only.",
        exitCode: 64
      )
    }
  }

  private func resolvedProductName(from generatedPackage: SwiftWebGeneratedPackage) throws -> String
  {
    if let product {
      return product
    }
    if buildsWasmRuntime {
      guard let wasmProduct = generatedPackage.wasmProductNames.first else {
        throw CLIError(message: "no generated WASM runtime product was found", exitCode: 66)
      }
      return wasmProduct
    }
    return generatedPackage.serverProductName
  }

  private func resolvedWasmRuntime(
    productName: String,
    from generatedPackage: SwiftWebGeneratedPackage
  ) throws -> SwiftWebGeneratedWasmRuntime? {
    guard buildsWasmRuntime else {
      return nil
    }
    guard
      let runtime = generatedPackage.wasmRuntimes.first(where: { $0.productName == productName })
    else {
      throw CLIError(
        message: "no generated WASM runtime matched product \(productName)", exitCode: 66)
    }
    return runtime
  }

  private func defaultScratchDirectory(from generatedPackage: SwiftWebGeneratedPackage) -> URL? {
    let child = buildsWasmRuntime ? "wasm" : "server"
    return generatedPackage.rootDirectory
      .appendingPathComponent(".build", isDirectory: true)
      .appendingPathComponent(child, isDirectory: true)
      .standardizedFileURL
  }

  private func resolvedSwiftSDKName() throws -> String? {
    if buildsWasmRuntime {
      let baseSDK =
        swiftSDK
        ?? ProcessInfo.processInfo.environment["SWIFT_WEB_WASM_SDK"]
        ?? SwiftWebWasmToolchain.defaultSwiftSDKName
      if baseSDK.contains("embedded") {
        throw CLIError(
          message:
            "unsupported Swift SDK for SwiftWeb WASM: \(baseSDK). SwiftWeb supports the standard WASM SDK only.",
          exitCode: 64
        )
      }
      return baseSDK
    }
    return swiftSDK
  }

  private func resolvedWasmToolchain(swiftSDK: String?) throws -> SwiftWebWasmToolchain? {
    guard buildsWasmRuntime else {
      return nil
    }
    return try SwiftWebWasmToolchain.resolve(
      sdkName: swiftSDK ?? SwiftWebWasmToolchain.defaultSwiftSDKName
    )
  }

  private func runProcess(
    arguments: [String],
    executableURL: URL,
    environment: [String: String]
  ) throws {
    let process = Process()
    process.executableURL = executableURL
    process.arguments = arguments
    process.currentDirectoryURL = packageDirectory
    process.environment = environment
    process.standardInput = FileHandle.standardInput
    process.standardOutput = FileHandle.standardOutput
    process.standardError = FileHandle.standardError

    try process.run()
    process.waitUntilExit()
    guard process.terminationStatus == 0 else {
      throw CLIError(
        message:
          "build failed with status \(process.terminationStatus): \(commandDescription(arguments, executableURL: executableURL))",
        exitCode: 70
      )
    }
  }

  private func processWasmArtifact(
    runtime: SwiftWebGeneratedWasmRuntime,
    scratchDirectory: URL?,
    configuration: String
  ) throws {
    let artifactURL = try SwiftPMWasmArtifact.url(
      anchorFile: runtime.packageDirectory
        .appendingPathComponent("Package.swift")
        .path,
      target: runtime.targetName,
      artifactName: runtime.productName,
      configuration: configuration,
      scratchDirectory: scratchDirectory
    )
    let result = try SwiftWebWasmArtifactProcessor(options: .production())
      .process(fileURL: artifactURL)
    let gzipDescription = result.gzipBytes.map(String.init) ?? "unavailable"
    let brotliDescription = result.brotliBytes.map(String.init) ?? "unavailable"
    print(
      """
      SwiftWeb WASM artifact:
        path: \(result.artifactURL.path)
        original: \(result.originalBytes) bytes
        final: \(result.finalBytes) bytes
        gzip: \(gzipDescription) bytes
        brotli: \(brotliDescription) bytes
        report: \(result.reportURL?.path ?? "unavailable")
      """
    )
    for warning in result.warnings {
      print("SwiftWeb WASM warning: \(warning)")
    }
  }

  private func commandDescription(_ arguments: [String], executableURL: URL?) -> String {
    let launcher = executableURL?.path ?? "env"
    return ([launcher] + arguments).joined(separator: " ")
  }
}
