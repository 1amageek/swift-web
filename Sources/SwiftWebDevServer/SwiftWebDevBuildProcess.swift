import SwiftWebDevelopmentHooks
import SwiftWebPackageGeneration
import SwiftWebWasmBuild
import CryptoKit
import Foundation
import SwiftHTML
import SwiftWebCore

struct SwiftWebDevBuildProcess: Sendable {
  let configuration: SwiftWebDevRuntimeConfiguration

  func buildWasmRuntime(
    _ runtime: SwiftWebGeneratedWasmRuntime
  ) throws -> ClientRuntimeHMRManifest {
    let sdkName = wasmSwiftSDK
    guard !sdkName.contains("embedded") else {
      throw SwiftWebDevRuntimeError.unsupportedWasmSDK(sdkName)
    }
    let toolchain = try SwiftWebWasmToolchain.resolve(sdkName: sdkName)
    let artifactProcessingOptions = SwiftWebWasmArtifactProcessor.Options.development()
    let packageDirectory = runtime.packageDirectory
    let scratchDirectory = wasmScratchDirectory
    let existingArtifactURL = try SwiftPMWasmArtifact.url(
      anchorFile:
        packageDirectory
        .appendingPathComponent("Package.swift")
        .path,
      target: runtime.targetName,
      artifactName: runtime.productName,
      scratchDirectory: scratchDirectory
    )
    let inputHash = try SwiftWebWasmBuildInputHasher.hash(
      runtime: runtime,
      sdkName: sdkName,
      swiftExecutablePath: toolchain.swiftExecutableURL.path,
      artifactProcessingSignature: artifactProcessingOptions.inputSignature
    )
    let artifactCache = SwiftWebDevWasmArtifactCache()
    if let cachedManifest = try cachedWasmManifest(
      runtime: runtime,
      artifactURL: existingArtifactURL,
      inputHash: inputHash,
      artifactProcessingOptions: artifactProcessingOptions
    ) {
      return cachedManifest
    }
    do {
      if let restoredArtifactHash = try artifactCache.restore(
        inputHash: inputHash,
        to: existingArtifactURL
      ) {
        try writeBuildStamp(
          SwiftWebWasmBuildStamp(inputHash: inputHash, artifactHash: restoredArtifactHash),
          for: runtime
        )
        if let cachedManifest = try cachedWasmManifest(
          runtime: runtime,
          artifactURL: existingArtifactURL,
          inputHash: inputHash,
          artifactProcessingOptions: artifactProcessingOptions
        ) {
          return cachedManifest
        }
      }
    } catch {
      writeWarning("SwiftWeb WASM artifact cache restore skipped: \(String(describing: error))")
    }

    var arguments = swiftBuildArguments(
      packageDirectory: packageDirectory,
      scratchDirectory: scratchDirectory
    )
    arguments.append("--quiet")
    arguments.append("--product")
    arguments.append(runtime.productName)
    arguments.append("-c")
    arguments.append("release")
    arguments.append("--swift-sdk")
    arguments.append(sdkName)

    var environment = try processEnvironment(
      toolchain: toolchain,
      scratchDirectory: scratchDirectory
    )
    environment["SWIFTWEB_WASM_BUILD"] = "1"
    environment["SWIFTWEB_CORE_ONLY"] = "1"

    try runProcess(
      arguments: arguments,
      environment: environment,
      executableURL: toolchain.swiftExecutableURL,
      packageDirectory: packageDirectory
    )
    let artifactURL = try SwiftPMWasmArtifact.url(
      anchorFile:
        packageDirectory
        .appendingPathComponent("Package.swift")
        .path,
      target: runtime.targetName,
      artifactName: runtime.productName,
      scratchDirectory: scratchDirectory
    )
    let processingResult = try SwiftWebWasmArtifactProcessor(options: artifactProcessingOptions)
      .process(fileURL: artifactURL)
    let hash = processingResult.contentHash
    try writeBuildStamp(
      SwiftWebWasmBuildStamp(inputHash: inputHash, artifactHash: hash),
      for: runtime
    )
    do {
      try artifactCache.store(inputHash: inputHash, artifactURL: artifactURL, artifactHash: hash)
    } catch {
      writeWarning("SwiftWeb WASM artifact cache store skipped: \(String(describing: error))")
    }
    let schemaHashes = try schemaHashes(for: runtime)

    return ClientRuntimeHMRManifest(
      componentTypeName: runtime.componentTypeName,
      bundleID: runtime.bundleID,
      assetPath: "\(runtime.assetPath)?v=\(hash)",
      contentHash: hash,
      stateSchemaHash: schemaHashes.stateSchemaHash,
      environmentSchemaHash: schemaHashes.environmentSchemaHash
    )
  }

  private func cachedWasmManifest(
    runtime: SwiftWebGeneratedWasmRuntime,
    artifactURL: URL,
    inputHash: String,
    artifactProcessingOptions: SwiftWebWasmArtifactProcessor.Options
  ) throws -> ClientRuntimeHMRManifest? {
    guard FileManager.default.fileExists(atPath: artifactURL.path) else {
      return nil
    }
    guard let stamp = try readBuildStamp(for: runtime), stamp.inputHash == inputHash else {
      return nil
    }
    let data = try Data(contentsOf: artifactURL, options: [.mappedIfSafe])
    let artifactHash = SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined()
    guard stamp.artifactHash == artifactHash else {
      return nil
    }
    let processingResult = try SwiftWebWasmArtifactProcessor(options: artifactProcessingOptions)
      .process(fileURL: artifactURL)
    if processingResult.contentHash != artifactHash {
      try writeBuildStamp(
        SwiftWebWasmBuildStamp(
          inputHash: inputHash,
          artifactHash: processingResult.contentHash
        ),
        for: runtime
      )
    }
    let schemaHashes = try schemaHashes(for: runtime)
    return ClientRuntimeHMRManifest(
      componentTypeName: runtime.componentTypeName,
      bundleID: runtime.bundleID,
      assetPath: "\(runtime.assetPath)?v=\(processingResult.contentHash)",
      contentHash: processingResult.contentHash,
      stateSchemaHash: schemaHashes.stateSchemaHash,
      environmentSchemaHash: schemaHashes.environmentSchemaHash
    )
  }

  private func schemaHashes(for runtime: SwiftWebGeneratedWasmRuntime) throws
    -> SwiftWebDevClientManifestSchemaHashes
  {
    try SwiftWebDevClientManifestSnapshotStore(
      fileURL: SwiftWebDevClientManifestSnapshotStore.fileURL(for: configuration)
    )
    .schemaHashes(for: runtime)
  }

  private func readBuildStamp(
    for runtime: SwiftWebGeneratedWasmRuntime
  ) throws -> SwiftWebWasmBuildStamp? {
    let url = buildStampURL(for: runtime)
    guard FileManager.default.fileExists(atPath: url.path) else {
      return nil
    }
    let data = try Data(contentsOf: url)
    return try JSONDecoder().decode(SwiftWebWasmBuildStamp.self, from: data)
  }

  private func writeBuildStamp(
    _ stamp: SwiftWebWasmBuildStamp,
    for runtime: SwiftWebGeneratedWasmRuntime
  ) throws {
    let url = buildStampURL(for: runtime)
    try FileManager.default.createDirectory(
      at: url.deletingLastPathComponent(),
      withIntermediateDirectories: true
    )
    let data = try JSONEncoder().encode(stamp)
    try data.write(to: url, options: [.atomic])
  }

  private func buildStampURL(for runtime: SwiftWebGeneratedWasmRuntime) -> URL {
    buildStampDirectory
      .appendingPathComponent("\(runtime.productName).json")
  }

  private var buildStampDirectory: URL {
    if let scratchDirectory = wasmScratchDirectory {
      return
        scratchDirectory
        .appendingPathComponent("build-stamps", isDirectory: true)
        .standardizedFileURL
    }

    return configuration.packageDirectory
      .appendingPathComponent(".build", isDirectory: true)
      .appendingPathComponent("wasm-build-stamps", isDirectory: true)
      .standardizedFileURL
  }

  private func swiftBuildArguments(
    packageDirectory: URL,
    scratchDirectory: URL?
  ) -> [String] {
    var arguments = [
      "build",
      "--disable-sandbox",
      "--package-path",
      packageDirectory.path,
    ]

    if let scratchDirectory {
      arguments.append("--scratch-path")
      arguments.append(scratchDirectory.path)
    }

    return arguments
  }

  private func runProcess(
    arguments: [String],
    environment: [String: String],
    executableURL: URL,
    packageDirectory: URL
  ) throws {
    let process = Process()
    let outputLog = try SwiftWebDevCapturedProcessLog.create(prefix: "swiftweb-dev-wasm-build")
    defer {
      outputLog.close()
      outputLog.cleanup()
    }
    process.executableURL = executableURL
    process.arguments = arguments
    process.currentDirectoryURL = packageDirectory
    process.environment = environment
    process.standardInput = FileHandle.standardInput
    process.standardOutput = outputLog.handle
    process.standardError = outputLog.handle

    try process.run()
    process.waitUntilExit()
    outputLog.close()
    guard process.terminationStatus == 0 else {
      outputLog.writeToStandardError()
      throw SwiftWebDevRuntimeError.processFailed(
        command: commandDescription(arguments, executableURL: executableURL),
        status: process.terminationStatus
      )
    }
  }

  private func processEnvironment(
    toolchain: SwiftWebWasmToolchain,
    scratchDirectory: URL?
  ) throws -> [String: String] {
    let moduleCacheDirectory = self.moduleCacheDirectory(scratchDirectory: scratchDirectory)
    let temporaryDirectory = self.temporaryDirectory(scratchDirectory: scratchDirectory)
    try FileManager.default.createDirectory(
      at: moduleCacheDirectory,
      withIntermediateDirectories: true
    )
    try FileManager.default.createDirectory(
      at: temporaryDirectory,
      withIntermediateDirectories: true
    )

    var environment = ProcessInfo.processInfo.environment
    environment["SWIFTPM_MODULECACHE_OVERRIDE"] = moduleCacheDirectory.path
    environment["CLANG_MODULE_CACHE_PATH"] = moduleCacheDirectory.path
    environment["TMPDIR"] = temporaryDirectory.path + "/"
    environment["TMP"] = temporaryDirectory.path
    environment["TEMP"] = temporaryDirectory.path
    return toolchain.applying(to: environment)
  }

  private func commandDescription(_ arguments: [String], executableURL: URL) -> String {
    ([executableURL.path] + arguments).joined(separator: " ")
  }

  private func writeWarning(_ message: String) {
    guard let data = "\(message)\n".data(using: .utf8) else {
      return
    }
    FileHandle.standardError.write(data)
  }

  private var wasmSwiftSDK: String {
    ProcessInfo.processInfo.environment["SWIFT_WEB_WASM_SDK"]
      ?? SwiftWebWasmToolchain.defaultSwiftSDKName
  }

  private var wasmScratchDirectory: URL? {
    SwiftWebDevWasmScratchDirectory.resolve(from: configuration.scratchDirectory)
  }

  private func moduleCacheDirectory(scratchDirectory: URL?) -> URL {
    if let scratchDirectory {
      return
        scratchDirectory
        .appendingPathComponent("swiftpm-module-cache", isDirectory: true)
        .standardizedFileURL
    }

    return configuration.packageDirectory
      .appendingPathComponent(".build", isDirectory: true)
      .appendingPathComponent("wasm-module-cache", isDirectory: true)
      .standardizedFileURL
  }

  private func temporaryDirectory(scratchDirectory: URL?) -> URL {
    if let scratchDirectory {
      return
        scratchDirectory
        .appendingPathComponent("tmp", isDirectory: true)
        .standardizedFileURL
    }

    return configuration.packageDirectory
      .appendingPathComponent(".build", isDirectory: true)
      .appendingPathComponent("tmp", isDirectory: true)
      .standardizedFileURL
  }
}
