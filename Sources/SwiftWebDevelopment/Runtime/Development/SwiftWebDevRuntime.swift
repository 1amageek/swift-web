import Foundation
import Logging
import SwiftWebDevelopmentHooks

public struct SwiftWebDevRuntime {
  private let configuration: SwiftWebDevRuntimeConfiguration
  private let logger: Logger
  private let childStatusCheckInterval: TimeInterval = 1

  public init(configuration: SwiftWebDevRuntimeConfiguration) {
    self.configuration = configuration
    self.logger = SwiftWebDevRuntime.makeLogger(for: configuration)
  }

  init(
    configuration: SwiftWebDevRuntimeConfiguration,
    logger: Logger
  ) {
    self.configuration = configuration
    self.logger = logger
  }

  public func run() async throws {
    let packageFile = configuration.packageDirectory.appendingPathComponent("Package.swift")
    guard FileManager.default.fileExists(atPath: packageFile.path) else {
      logger.error(
        "SwiftWeb dev package manifest was not found",
        metadata: metadata([
          "package": .string(configuration.packageDirectory.path)
        ])
      )
      throw SwiftWebDevRuntimeError.packageManifestNotFound(configuration.packageDirectory)
    }

    let materializer = SwiftWebGeneratedPackageMaterializer(
      appPackageDirectory: configuration.packageDirectory,
      serverProductName: configuration.product
    )
    let generatedPackage = try materializer.materialize()
    let serverConfiguration = SwiftWebDevRuntimeConfiguration(
      packageDirectory: generatedPackage.devPackageDirectory,
      scratchDirectory: configuration.scratchDirectory
        ?? Self.defaultServerScratchDirectory(for: generatedPackage),
      product: generatedPackage.developmentServerProductName,
      host: "127.0.0.1",
      port: 0,
      readinessTimeout: configuration.readinessTimeout
    )
    let dependencyRoots = try SwiftWebDevLocalPackageDependencyResolver.localPackageRoots(
      for: configuration.packageDirectory
    )
    let watchRoots = uniqueRoots([configuration.packageDirectory] + dependencyRoots)

    let eventLog = SwiftWebDevEventLog(
      fileURL: SwiftWebDevEventLog.fileURL(for: serverConfiguration))
    try eventLog.reset()
    let devToken = UUID().uuidString
    let workerRegistry = SwiftWebDevWorkerRegistry()
    let devHost = SwiftWebDevHost(
      configuration: configuration,
      devToken: devToken,
      eventLog: eventLog,
      workerRegistry: workerRegistry,
      logger: logger
    )
    var server = SwiftWebDevServerProcess(
      configuration: try workerConfiguration(from: serverConfiguration),
      devToken: devToken
    )
    let watcher = SwiftWebDevFileChangeWatcher(roots: watchRoots)
    let buildProcess = SwiftWebDevBuildProcess(configuration: serverConfiguration)
    SwiftWebDevSignalHandler.install()

    logger.info(
      "SwiftWeb dev server starting at \(url)",
      metadata: metadata([
        "generatedPackage": .string(generatedPackage.rootDirectory.path),
        "serverPackage": .string(generatedPackage.packageDirectory.path),
        "devPackage": .string(generatedPackage.devPackageDirectory.path),
        "wasmPackage": .string(generatedPackage.wasmPackageDirectory.path),
        "watchRootCount": .string(String(watchRoots.count)),
        "watchRoots": .string(watchRoots.map(\.path).joined(separator: ",")),
      ])
    )

    do {
      guard !SwiftWebDevPortProbe.isListening(host: configuration.host, port: configuration.port)
      else {
        logger.error("SwiftWeb dev port is already in use", metadata: metadata())
        throw SwiftWebDevRuntimeError.portInUse(host: configuration.host, port: configuration.port)
      }

      try await devHost.start()

      try buildInitialWasmRuntimes(
        generatedPackage.wasmRuntimes,
        eventLog: eventLog,
        buildProcess: buildProcess
      )

      logger.info("SwiftWeb dev child product building and starting", metadata: metadata())
      do {
        try server.start()
      } catch {
        logger.error(
          "SwiftWeb dev child process failed to start",
          metadata: metadata([
            "error": .string(String(describing: error))
          ])
        )
        throw error
      }
      if SwiftWebDevPortProbe.wait(
        host: server.target.host,
        port: server.target.port,
        timeout: configuration.readinessTimeout
      ) {
        workerRegistry.activate(server.target)
        logger.info("SwiftWeb dev server ready at \(url)", metadata: metadata())
      } else {
        logger.warning(
          "SwiftWeb dev server did not become ready before startup timeout",
          metadata: metadata([
            "readinessTimeoutSeconds": .string(String(configuration.readinessTimeout))
          ])
        )
        throw SwiftWebDevRuntimeError.workerReadinessTimeout(
          host: server.target.host,
          port: server.target.port,
          timeout: configuration.readinessTimeout
        )
      }
      watcher.discardPendingChanges()

      while !SwiftWebDevSignalHandler.shouldStop {
        let changes = watcher.waitForChangeSet(timeout: childStatusCheckInterval)
        if !changes.isEmpty {
          let refreshedGeneratedPackage = try materializer.materialize()
          let classifier = SwiftWebDevChangeClassifier(
            appPackageDirectory: configuration.packageDirectory,
            generatedPackage: refreshedGeneratedPackage
          )
          let plan = classifier.classify(changes)
          logger.info(
            "SwiftWeb dev change detected",
            metadata: metadata([
              "changedPaths": .string(plan.changedPaths.joined(separator: ",")),
              "styleFileCount": .string(String(plan.styleFiles.count)),
              "clientRuntimeCount": .string(String(plan.clientRuntimes.count)),
              "requiresServerRestart": .string(String(plan.requiresServerRestart)),
            ])
          )
          try handle(
            plan: plan,
            eventLog: eventLog,
            buildProcess: buildProcess,
            serverConfiguration: serverConfiguration,
            workerRegistry: workerRegistry,
            devToken: devToken,
            server: &server
          )
        } else if let terminationStatus = server.clearExitedProcess() {
          workerRegistry.markUnavailable(
            message: "SwiftWeb worker exited",
            detail: "terminationStatus=\(terminationStatus)"
          )
          logger.warning(
            "SwiftWeb dev child process exited. Waiting for changes",
            metadata: metadata([
              "terminationStatus": .string(String(terminationStatus))
            ])
          )
        }
      }
    } catch {
      logger.info("SwiftWeb dev server stopping", metadata: metadata())
      server.stop()
      await devHost.stop()
      throw error
    }

    logger.info("SwiftWeb dev server stopping", metadata: metadata())
    server.stop()
    await devHost.stop()
  }

  private func buildInitialWasmRuntimes(
    _ runtimes: [SwiftWebGeneratedWasmRuntime],
    eventLog: SwiftWebDevEventLog,
    buildProcess: SwiftWebDevBuildProcess
  ) throws {
    guard !runtimes.isEmpty else {
      return
    }

    logger.info(
      "SwiftWeb dev initial client WASM build starting",
      metadata: metadata([
        "runtimeCount": .string(String(runtimes.count))
      ])
    )

    for runtime in runtimes {
      do {
        _ = try buildProcess.buildWasmRuntime(runtime)
        logger.info(
          "SwiftWeb dev initial client WASM build completed",
          metadata: metadata([
            "component": .string(runtime.componentTypeName),
            "product": .string(runtime.productName),
          ])
        )
      } catch {
        let runtimeError = SwiftWebDevRuntimeError.initialWasmBuildFailed(
          component: runtime.componentTypeName,
          product: runtime.productName,
          reason: String(describing: error)
        )
        do {
          try eventLog.append(
            SwiftWebDevEvent(
              kind: .error,
              message: runtimeError.description
            ))
        } catch {
          logger.error(
            "SwiftWeb dev failed to record initial client WASM build error",
            metadata: metadata([
              "component": .string(runtime.componentTypeName),
              "product": .string(runtime.productName),
              "error": .string(String(describing: error)),
            ])
          )
        }
        logger.error(
          "SwiftWeb dev initial client WASM build failed",
          metadata: metadata([
            "component": .string(runtime.componentTypeName),
            "product": .string(runtime.productName),
            "error": .string(String(describing: error)),
          ])
        )
        throw runtimeError
      }
    }
  }

  private func handle(
    plan: SwiftWebDevChangePlan,
    eventLog: SwiftWebDevEventLog,
    buildProcess: SwiftWebDevBuildProcess,
    serverConfiguration: SwiftWebDevRuntimeConfiguration,
    workerRegistry: SwiftWebDevWorkerRegistry,
    devToken: String,
    server: inout SwiftWebDevServerProcess
  ) throws {
    guard !plan.isEmpty else {
      return
    }

    for styleFile in plan.styleFiles {
      do {
        let css = try String(contentsOf: styleFile, encoding: .utf8)
        try eventLog.append(
          SwiftWebDevEvent(
            kind: .stylePatch,
            stylePatch: SwiftWebDevStylePatch(
              id: "dev-style-hmr-\(abs(styleFile.path.hashValue))",
              css: css
            ),
            changedPaths: plan.changedPaths
          ))
        logger.info(
          "SwiftWeb dev style HMR event emitted",
          metadata: metadata(["styleFile": .string(styleFile.path)])
        )
      } catch {
        try eventLog.append(
          SwiftWebDevEvent(
            kind: .error,
            message: "Style HMR failed: \(String(describing: error))",
            changedPaths: plan.changedPaths
          ))
        logger.error(
          "SwiftWeb dev style HMR failed",
          metadata: metadata([
            "styleFile": .string(styleFile.path),
            "error": .string(String(describing: error)),
          ])
        )
      }
    }

    for runtime in plan.clientRuntimes {
      do {
        try eventLog.append(
          SwiftWebDevEvent(
            kind: .clientBuildStarted,
            message: "SwiftWeb Client WASM rebuilding",
            changedPaths: plan.changedPaths
          ))
        let manifest = try buildProcess.buildWasmRuntime(runtime)
        try eventLog.append(
          SwiftWebDevEvent(
            kind: .clientComponentUpdate,
            clientComponentUpdate: manifest,
            changedPaths: plan.changedPaths
          ))
        logger.info(
          "SwiftWeb dev client component HMR event emitted",
          metadata: metadata([
            "component": .string(runtime.componentTypeName),
            "product": .string(runtime.productName),
          ])
        )
      } catch {
        try eventLog.append(
          SwiftWebDevEvent(
            kind: .error,
            message:
              "Client WASM HMR failed for \(runtime.componentTypeName): \(String(describing: error))",
            changedPaths: plan.changedPaths
          ))
        logger.error(
          "SwiftWeb dev client component HMR failed",
          metadata: metadata([
            "component": .string(runtime.componentTypeName),
            "product": .string(runtime.productName),
            "error": .string(String(describing: error)),
          ])
        )
      }
    }

    guard plan.requiresServerRestart else {
      return
    }

    try eventLog.append(
      SwiftWebDevEvent(
        kind: .serverBuildStarted,
        message: "SwiftWeb server rebuilding",
        changedPaths: plan.changedPaths
      ))
    workerRegistry.markBuilding(
      message: "SwiftWeb server rebuilding",
      detail: plan.changedPaths.joined(separator: ",")
    )
    logger.info(
      "SwiftWeb dev server rebuild required",
      metadata: metadata([
        "reasons": .string(plan.serverRestartReasons.joined(separator: ","))
      ])
    )
    logger.info("SwiftWeb dev child process building replacement", metadata: metadata())
    var replacement = SwiftWebDevServerProcess(
      configuration: try workerConfiguration(from: serverConfiguration),
      devToken: devToken
    )
    do {
      try replacement.start()
    } catch {
      replacement.stop()
      workerRegistry.markError(
        message: "SwiftWeb server rebuild failed",
        detail: String(describing: error)
      )
      try eventLog.append(
        SwiftWebDevEvent(
          kind: .error,
          message: "Server restart failed: \(String(describing: error))",
          changedPaths: plan.changedPaths
        ))
      logger.error(
        "SwiftWeb dev child replacement failed to start",
        metadata: metadata([
          "error": .string(String(describing: error))
        ])
      )
      throw error
    }
    if SwiftWebDevPortProbe.wait(
      host: replacement.target.host,
      port: replacement.target.port,
      timeout: configuration.readinessTimeout
    ) {
      let oldServer = server
      server = replacement
      workerRegistry.activate(replacement.target)
      var stoppedServer = oldServer
      stoppedServer.stop()
      try eventLog.append(
        SwiftWebDevEvent(
          kind: .serverRestarted,
          message: "SwiftWeb server restarted",
          changedPaths: plan.changedPaths
        ))
      logger.info("SwiftWeb dev server ready after reload at \(url)", metadata: metadata())
    } else {
      replacement.stop()
      workerRegistry.markError(
        message: "SwiftWeb server rebuild timed out",
        detail: "\(replacement.target.url) did not become ready"
      )
      logger.warning(
        "SwiftWeb dev server did not become ready before reload timeout",
        metadata: metadata([
          "readinessTimeoutSeconds": .string(String(configuration.readinessTimeout))
        ])
      )
      try eventLog.append(
        SwiftWebDevEvent(
          kind: .error,
          message: "Server restart failed: worker did not become ready",
          changedPaths: plan.changedPaths
        ))
      throw SwiftWebDevRuntimeError.workerReadinessTimeout(
        host: replacement.target.host,
        port: replacement.target.port,
        timeout: configuration.readinessTimeout
      )
    }
  }

  private func workerConfiguration(from serverConfiguration: SwiftWebDevRuntimeConfiguration) throws
    -> SwiftWebDevRuntimeConfiguration
  {
    var configuration = serverConfiguration
    configuration.host = "127.0.0.1"
    configuration.port = try SwiftWebDevPortAllocator.allocateLoopbackPort()
    return configuration
  }

  private func uniqueRoots(_ roots: [URL]) -> [URL] {
    var seen = Set<String>()
    var output: [URL] = []

    for root in roots {
      let standardizedRoot = root.standardizedFileURL
      if seen.insert(standardizedRoot.path).inserted {
        output.append(standardizedRoot)
      }
    }

    return output
  }

  private static func defaultServerScratchDirectory(for generatedPackage: SwiftWebGeneratedPackage)
    -> URL
  {
    generatedPackage.rootDirectory
      .appendingPathComponent(".build", isDirectory: true)
      .appendingPathComponent("server", isDirectory: true)
      .standardizedFileURL
  }

  private var url: String {
    "http://\(configuration.host):\(configuration.port)"
  }

  private func metadata(_ extra: Logger.Metadata = [:]) -> Logger.Metadata {
    var values: Logger.Metadata = [
      "url": .string(url),
      "host": .string(configuration.host),
      "port": .string(String(configuration.port)),
      "product": .string(configuration.product),
      "package": .string(configuration.packageDirectory.path),
    ]

    if let scratchDirectory = configuration.scratchDirectory {
      values["scratch"] = .string(scratchDirectory.path)
    }

    for (key, value) in extra {
      values[key] = value
    }

    return values
  }

  private static func makeLogger(for configuration: SwiftWebDevRuntimeConfiguration) -> Logger {
    var logger = Logger(label: "codes.swiftweb.dev")
    logger[metadataKey: "package"] = .string(configuration.packageDirectory.path)
    logger[metadataKey: "product"] = .string(configuration.product)
    logger[metadataKey: "url"] = .string("http://\(configuration.host):\(configuration.port)")
    return logger
  }
}
