import Foundation
import SwiftWebCore
import SwiftWebDevelopment

struct SwiftWebGeneratedPackageBuilder {
  let packageDirectory: URL
  let scratchDirectory: URL?
  let product: String?
  let buildsWasmRuntime: Bool
  let swiftSDK: String?
  let configuration: String?
  let wasmRuntimeProfile: SwiftWebWasmRuntimeProfile

  func run() async throws {
    let resolvedSwiftSDK = try resolvedSwiftSDKName()
    let wasmToolchain = try resolvedWasmToolchain(swiftSDK: resolvedSwiftSDK)
    let generatedPackage = try SwiftWebGeneratedPackageMaterializer(
      appPackageDirectory: packageDirectory,
      serverProductName: product ?? "app-server",
      wasmRuntimeProfile: wasmRuntimeProfile
    )
    .materialize()
    guard let productName = try resolvedProductName(from: generatedPackage) else {
      print("SwiftWeb browser runtime is not required by this application")
      return
    }
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
    if buildsWasmRuntime,
      wasmRuntimeProfile == .embedded,
      let wasmToolchain
    {
      let unicodeDataTables = try wasmToolchain.embeddedUnicodeDataTablesLibraryURL()
      arguments.append(contentsOf: [
        "-Xswiftc", "-Xlinker",
        "-Xswiftc", unicodeDataTables.path,
      ])
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

    let invocation: SwiftBuildInvocation
    if let wasmToolchain {
      invocation = .wasm(toolchain: wasmToolchain)
    } else {
      invocation = try .host(packageDirectory: packageDirectory, environment: environment)
    }
    try await runProcess(
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

  private func resolvedProductName(
    from generatedPackage: SwiftWebGeneratedPackage
  ) throws -> String?
  {
    if let product {
      return product
    }
    if buildsWasmRuntime {
      return generatedPackage.wasmProductNames.first
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
        ?? wasmRuntimeProfile.defaultSwiftSDKName
      guard wasmRuntimeProfile.supports(swiftSDKName: baseSDK) else {
        throw CLIError(
          message:
            "Swift SDK \(baseSDK) does not match the \(wasmRuntimeProfile.rawValue) WASM runtime profile.",
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
      sdkName: swiftSDK ?? wasmRuntimeProfile.defaultSwiftSDKName
    )
  }

  private func runProcess(
    arguments: [String],
    executableURL: URL,
    environment: [String: String]
  ) async throws {
    let process = Process()
    process.executableURL = executableURL
    process.arguments = arguments
    process.currentDirectoryURL = packageDirectory
    process.environment = environment
    process.standardInput = FileHandle.standardInput
    process.standardOutput = FileHandle.standardOutput
    process.standardError = FileHandle.standardError

    let status = try await SwiftWebLifecycleCommandRunner().run(process)
    guard status == 0 else {
      throw CLIError(
        message:
          "build failed with status \(status): \(commandDescription(arguments, executableURL: executableURL))",
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
