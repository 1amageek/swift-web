import SwiftWebPackageGeneration
import SwiftWebWasmBuild
import Foundation
import Logging
import SwiftWebDevelopmentHooks
import Synchronization

public struct SwiftWebDevRuntime: Sendable {
  private let configuration: SwiftWebDevRuntimeConfiguration
  private let logger: Logger

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

  /// Bootstraps the dev host and hands the loop to the reconciler.
  ///
  /// Error policy (docs/DevServerReconcilerDesign.md §4.4): environment
  /// errors that no file edit can fix — missing manifest, occupied port, dev
  /// host or initial WASM failure — still throw and exit. Everything after
  /// the dev host is listening is reconciler state: app compile errors and
  /// worker crashes surface through status and events, never as an exit.
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
      readinessTimeout: configuration.readinessTimeout,
      hostSwiftExecutableURL: configuration.hostSwiftExecutableURL
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
    // FSEvents fire before the reconciler exists; the relay buffers the
    // wiring, not the events — a pre-wiring event is only a lost *hint*, the
    // first timer tick converges regardless.
    let wakeRelay = SwiftWebDevWakeRelay()
    let watcher = SwiftWebDevFileChangeWatcher(
      roots: watchRoots,
      onFileEvent: { wakeRelay.invoke() }
    )
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

    guard !SwiftWebDevPortProbe.isListening(host: configuration.host, port: configuration.port)
    else {
      logger.error("SwiftWeb dev port is already in use", metadata: metadata())
      throw SwiftWebDevRuntimeError.portInUse(host: configuration.host, port: configuration.port)
    }

    try await devHost.start()

    do {
      try buildInitialWasmRuntimes(
        generatedPackage.wasmRuntimes,
        eventLog: eventLog,
        buildProcess: buildProcess
      )
    } catch {
      await devHost.stop()
      throw error
    }

    // ---- Reconciler wiring (docs/DevServerReconcilerDesign.md §4) ----

    let scanner = SwiftWebDevSourceFingerprintScanner(roots: watchRoots)
    let packageStore = SwiftWebDevGeneratedPackageStore(generatedPackage)
    let builder = SwiftWebDevWorkerBuilder(
      configuration: serverConfiguration,
      prepareInputs: {
        // Materialization is build preparation: it runs only on the build
        // path, never on css-only wakes (§4.6).
        let refreshed = try materializer.materialize()
        packageStore.update(refreshed)
      }
    )
    let launcher = SwiftWebDevWorkerLauncher(
      configuration: serverConfiguration,
      devToken: devToken
    )
    let observer = makeReconcilerObserver(
      workerRegistry: workerRegistry,
      eventLog: eventLog
    )
    let appPackageDirectory = configuration.packageDirectory
    let fastPath: @Sendable () async -> Void = {
      await applyFastPathChanges(
        watcher: watcher,
        appPackageDirectory: appPackageDirectory,
        packageStore: packageStore,
        eventLog: eventLog,
        buildProcess: buildProcess
      )
    }
    let reconciler = SwiftWebDevReconciler(
      fingerprinting: scanner,
      builder: builder,
      launcher: launcher,
      observer: observer,
      fastPath: fastPath
    )
    wakeRelay.setTarget { reconciler.wake() }
    workerRegistry.markStarting(message: "SwiftWeb dev worker building")

    let reconcilerTask = Task {
      await reconciler.run()
    }

    while !SwiftWebDevSignalHandler.shouldStop {
      do {
        try await Task.sleep(nanoseconds: 200_000_000)
      } catch {
        break
      }
    }

    logger.info("SwiftWeb dev server stopping", metadata: metadata())
    reconciler.shutdown()
    await reconcilerTask.value
    await reconciler.stopWorkerForShutdown()
    await devHost.stop()
  }

  // MARK: - Reconciler observer

  private func makeReconcilerObserver(
    workerRegistry: SwiftWebDevWorkerRegistry,
    eventLog: SwiftWebDevEventLog
  ) -> SwiftWebDevReconcilerObserver {
    let logger = self.logger
    let url = self.url
    let baseMetadata = metadata()
    let hasBuiltBefore = SwiftWebDevOnceFlag()
    let hasActivatedBefore = SwiftWebDevOnceFlag()

    let merged: @Sendable (Logger.Metadata) -> Logger.Metadata = { extra in
      var values = baseMetadata
      for (key, value) in extra {
        values[key] = value
      }
      return values
    }

    let append: @Sendable (SwiftWebDevEvent) -> Void = { event in
      do {
        try eventLog.append(event)
      } catch {
        logger.error(
          "SwiftWeb dev failed to record HMR event",
          metadata: merged(["error": .string(String(describing: error))])
        )
      }
    }

    var observer = SwiftWebDevReconcilerObserver()

    observer.transitionStarted = { fingerprint in
      workerRegistry.markBuilding(
        message: "SwiftWeb server rebuilding",
        detail: "sources \(fingerprint.short)"
      )
      append(SwiftWebDevEvent(kind: .serverBuildStarted, message: "SwiftWeb server rebuilding"))
      if hasBuiltBefore.consumeFirst() {
        logger.info(
          "SwiftWeb dev child product building and starting",
          metadata: merged(["fingerprint": .string(fingerprint.short)])
        )
      } else {
        logger.info(
          "SwiftWeb dev server rebuild required",
          metadata: merged(["reasons": .string("sources \(fingerprint.short)")])
        )
      }
    }

    observer.workerActivated = { handle, _ in
      workerRegistry.activate(handle.target)
      append(SwiftWebDevEvent(kind: .serverRestarted, message: "SwiftWeb server restarted"))
      let fingerprintMetadata = merged(["fingerprint": .string(handle.fingerprint.short)])
      if hasActivatedBefore.consumeFirst() {
        logger.info("SwiftWeb dev server ready at \(url)", metadata: fingerprintMetadata)
      } else {
        logger.info("SwiftWeb dev server ready after reload at \(url)", metadata: fingerprintMetadata)
      }
    }

    observer.transitionFailed = { fingerprint, error in
      let summary = String(describing: error)
      workerRegistry.markError(message: "SwiftWeb server rebuild failed", detail: summary)
      append(SwiftWebDevEvent(kind: .error, message: "Server rebuild failed: \(summary)"))
      logger.error(
        "SwiftWeb dev server build failed",
        metadata: merged([
          "fingerprint": .string(fingerprint.short),
          "errorSummary": .string(summary.split(separator: "\n").first.map(String.init) ?? summary),
          "error": .string(summary),
        ])
      )
    }

    observer.workerCrashed = { status, willRelaunch in
      if willRelaunch {
        workerRegistry.markRestarting(
          message: "SwiftWeb worker crashed; relaunching",
          detail: "terminationStatus=\(status)"
        )
        logger.warning(
          "SwiftWeb dev worker crashed; relaunching",
          metadata: merged(["terminationStatus": .string(String(status))])
        )
      } else {
        workerRegistry.markUnavailable(
          message: "SwiftWeb worker crash-looping",
          detail: "terminationStatus=\(status)"
        )
        append(SwiftWebDevEvent(kind: .error, message: "SwiftWeb worker is crash-looping"))
        logger.error(
          "SwiftWeb dev worker crash-looping; waiting for changes",
          metadata: merged(["terminationStatus": .string(String(status))])
        )
      }
    }

    observer.changesQueuedDuringTransition = { fingerprint in
      logger.info(
        "SwiftWeb dev changes queued during rebuild",
        metadata: merged(["sources": .string(fingerprint.short)])
      )
    }

    return observer
  }

  // MARK: - Fast path (§4.6)

  /// Emits style patches and rebuilds WASM client runtimes for the pending
  /// watcher diff. Best effort: failures become error events, never exits —
  /// the fingerprint covers the same files, so the reconciler's slow loop
  /// guarantees the served binary converges regardless.
  private func applyFastPathChanges(
    watcher: SwiftWebDevFileChangeWatcher,
    appPackageDirectory: URL,
    packageStore: SwiftWebDevGeneratedPackageStore,
    eventLog: SwiftWebDevEventLog,
    buildProcess: SwiftWebDevBuildProcess
  ) async {
    let changes = watcher.changes()
    guard !changes.isEmpty else {
      return
    }

    let classifier = SwiftWebDevChangeClassifier(
      appPackageDirectory: appPackageDirectory,
      generatedPackage: packageStore.current
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
        recordFastPathError(
          "Style HMR failed: \(String(describing: error))",
          changedPaths: plan.changedPaths,
          eventLog: eventLog
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
        recordFastPathError(
          "Client WASM HMR failed for \(runtime.componentTypeName): \(String(describing: error))",
          changedPaths: plan.changedPaths,
          eventLog: eventLog
        )
      }
    }
  }

  private func recordFastPathError(
    _ message: String,
    changedPaths: [String],
    eventLog: SwiftWebDevEventLog
  ) {
    logger.error(
      "SwiftWeb dev fast path failed",
      metadata: metadata(["error": .string(message)])
    )
    do {
      try eventLog.append(
        SwiftWebDevEvent(kind: .error, message: message, changedPaths: changedPaths)
      )
    } catch {
      logger.error(
        "SwiftWeb dev failed to record HMR event",
        metadata: metadata(["error": .string(String(describing: error))])
      )
    }
  }

  // MARK: - Initial WASM build

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

  // MARK: - Helpers

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

/// Buffers the FSEvents → reconciler wiring: the watcher starts before the
/// reconciler exists.
private final class SwiftWebDevWakeRelay: Sendable {
  private let target = Mutex<(@Sendable () -> Void)?>(nil)

  func setTarget(_ handler: @escaping @Sendable () -> Void) {
    target.withLock { $0 = handler }
  }

  func invoke() {
    let handler = target.withLock { $0 }
    handler?()
  }
}

/// Shares the freshest materialized package between the builder (which
/// refreshes it) and the fast path (which classifies against it).
private final class SwiftWebDevGeneratedPackageStore: Sendable {
  private let stored: Mutex<SwiftWebGeneratedPackage>

  init(_ package: SwiftWebGeneratedPackage) {
    self.stored = Mutex(package)
  }

  var current: SwiftWebGeneratedPackage {
    stored.withLock { $0 }
  }

  func update(_ package: SwiftWebGeneratedPackage) {
    stored.withLock { $0 = package }
  }
}

/// Returns true exactly once — distinguishes the first build/activation for
/// log wording.
private final class SwiftWebDevOnceFlag: Sendable {
  private let isFirst = Mutex(true)

  func consumeFirst() -> Bool {
    isFirst.withLock { value in
      let output = value
      value = false
      return output
    }
  }
}
