import Foundation
import Synchronization
import Testing

@testable import SwiftWebDevelopmentHooks
@testable import SwiftWebDevServer

@Suite
struct SwiftWebDevWorkerBuilderTests {
  @Test
  func binPathIsResolvedOnceAcrossBuilds() async throws {
    let root = try makeTemporaryRoot()
    defer { removeTemporaryRoot(root) }
    let binPath = root.appendingPathComponent("bin", isDirectory: true)
    try makeExecutable(at: binPath.appendingPathComponent("app-server-dev"))

    let runner = FakeCommandRunner(binPathOutput: binPath.path)
    let builder = SwiftWebDevWorkerBuilder(
      configuration: configuration(packageDirectory: root),
      commandRunner: runner
    )

    let first = try await builder.build()
    let second = try await builder.build()
    let third = try await builder.build()

    #expect(first.path == binPath.appendingPathComponent("app-server-dev").path)
    #expect(second == first)
    #expect(third == first)
    #expect(runner.captureCallCount == 1)
    #expect(runner.runCallCount == 3)
  }

  @Test
  func buildRunsPrepareInputsBeforeEveryBuild() async throws {
    let root = try makeTemporaryRoot()
    defer { removeTemporaryRoot(root) }
    let binPath = root.appendingPathComponent("bin", isDirectory: true)
    try makeExecutable(at: binPath.appendingPathComponent("app-server-dev"))

    let prepared = Counter()
    let builder = SwiftWebDevWorkerBuilder(
      configuration: configuration(packageDirectory: root),
      commandRunner: FakeCommandRunner(binPathOutput: binPath.path),
      prepareInputs: { prepared.increment() }
    )

    _ = try await builder.build()
    _ = try await builder.build()

    #expect(prepared.value == 2)
  }

  @Test
  func buildPropagatesRunnerFailure() async throws {
    let root = try makeTemporaryRoot()
    defer { removeTemporaryRoot(root) }
    let failure = SwiftWebDevRuntimeError.workerBuildFailed(
      command: "swift build",
      status: 1,
      firstErrorLine: "main.swift:1:1: error: expected expression",
      logPath: "/tmp/example.log"
    )
    let builder = SwiftWebDevWorkerBuilder(
      configuration: configuration(packageDirectory: root),
      commandRunner: FakeCommandRunner(binPathOutput: root.path, runError: failure)
    )

    await #expect(throws: SwiftWebDevRuntimeError.self) {
      _ = try await builder.build()
    }
  }

  @Test
  func missingExecutableThrowsExecutableNotFound() async throws {
    let root = try makeTemporaryRoot()
    defer { removeTemporaryRoot(root) }
    let emptyBinPath = root.appendingPathComponent("bin", isDirectory: true)
    try FileManager.default.createDirectory(at: emptyBinPath, withIntermediateDirectories: true)

    let builder = SwiftWebDevWorkerBuilder(
      configuration: configuration(packageDirectory: root),
      commandRunner: FakeCommandRunner(binPathOutput: emptyBinPath.path)
    )

    await #expect(throws: SwiftWebDevRuntimeError.self) {
      _ = try await builder.build()
    }
  }

  @Test
  func buildFailureCarriesFirstErrorLineAndLogPath() throws {
    let root = try makeTemporaryRoot()
    defer { removeTemporaryRoot(root) }
    let logURL = root.appendingPathComponent("build.log")
    try """
    Building for debugging...
    /app/Sources/App/Style.swift:12:8: error: cannot find type 'Colr' in scope
    note: did you mean 'Color'?
    """.write(to: logURL, atomically: true, encoding: .utf8)

    let error = SwiftWebDevSwiftCommandRunner.buildFailure(
      command: "swift build --product app-server-dev",
      status: 1,
      logURL: logURL
    )

    guard case .workerBuildFailed(let command, let status, let firstErrorLine, let logPath) = error else {
      Issue.record("Expected workerBuildFailed, got \(error)")
      return
    }
    #expect(command == "swift build --product app-server-dev")
    #expect(status == 1)
    #expect(firstErrorLine == "/app/Sources/App/Style.swift:12:8: error: cannot find type 'Colr' in scope")
    #expect(logPath == logURL.path)
    #expect(error.description.contains("error: cannot find type 'Colr' in scope"))
    #expect(error.description.contains(logURL.path))
  }

  // MARK: - Helpers

  private final class FakeCommandRunner: SwiftWebDevBuildCommandRunning {
    private let binPathOutput: String
    private let runError: SwiftWebDevRuntimeError?
    private let runCalls = Mutex(0)
    private let captureCalls = Mutex(0)

    init(binPathOutput: String, runError: SwiftWebDevRuntimeError? = nil) {
      self.binPathOutput = binPathOutput
      self.runError = runError
    }

    var runCallCount: Int {
      runCalls.withLock { $0 }
    }

    var captureCallCount: Int {
      captureCalls.withLock { $0 }
    }

    func run(arguments: [String]) async throws {
      runCalls.withLock { $0 += 1 }
      if let runError {
        throw runError
      }
    }

    func capture(arguments: [String]) async throws -> String {
      captureCalls.withLock { $0 += 1 }
      #expect(arguments.contains("--show-bin-path"))
      return binPathOutput + "\n"
    }
  }

  private final class Counter: Sendable {
    private let storage = Mutex(0)

    var value: Int {
      storage.withLock { $0 }
    }

    func increment() {
      storage.withLock { $0 += 1 }
    }
  }

  private func configuration(packageDirectory: URL) -> SwiftWebDevRuntimeConfiguration {
    SwiftWebDevRuntimeConfiguration(
      packageDirectory: packageDirectory,
      scratchDirectory: packageDirectory.appendingPathComponent("scratch", isDirectory: true),
      product: "app-server-dev",
      readinessTimeout: 2
    )
  }

  private func makeTemporaryRoot() throws -> URL {
    let root = FileManager.default.temporaryDirectory
      .appendingPathComponent("SwiftWebDevWorkerBuilderTests-\(UUID().uuidString)", isDirectory: true)
    try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
    return root
  }

  private func removeTemporaryRoot(_ root: URL) {
    do {
      try FileManager.default.removeItem(at: root)
    } catch {
      Issue.record("Worker builder test cleanup failed: \(String(describing: error))")
    }
  }

  private func makeExecutable(at url: URL) throws {
    try FileManager.default.createDirectory(
      at: url.deletingLastPathComponent(),
      withIntermediateDirectories: true
    )
    try "#!/bin/sh\nexit 0\n".write(to: url, atomically: true, encoding: .utf8)
    try FileManager.default.setAttributes(
      [.posixPermissions: 0o755],
      ofItemAtPath: url.path
    )
  }
}
