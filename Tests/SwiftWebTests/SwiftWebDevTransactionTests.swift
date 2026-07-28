import Foundation
import Synchronization
import Testing
import SwiftHTML

#if canImport(Darwin)
import Darwin
#elseif canImport(Glibc)
import Glibc
#endif

@testable import SwiftWebDevServer
@testable import SwiftWebDevelopmentHooks
@testable import SwiftWebPackageGeneration

@Suite
struct SwiftWebDevTransactionTests {
  @Test
  func fileTransactionRestoresExistingFilesAndRemovesNewFiles() throws {
    let directory = FileManager.default.temporaryDirectory
      .appendingPathComponent("swiftweb-file-transaction-test-\(UUID().uuidString)")
    try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    defer {
      do {
        try FileManager.default.removeItem(at: directory)
      } catch {
        Issue.record("Failed to clean transaction fixture: \(error)")
      }
    }

    let existingURL = directory.appendingPathComponent("existing.wasm")
    let newURL = directory.appendingPathComponent("new.stamp")
    try Data("before".utf8).write(to: existingURL)
    let transaction = try SwiftWebDevFileTransaction(fileURLs: [existingURL, newURL])

    try Data("after".utf8).write(to: existingURL)
    try Data("created".utf8).write(to: newURL)
    try transaction.rollback()
    try transaction.finish()

    #expect(try Data(contentsOf: existingURL) == Data("before".utf8))
    #expect(!FileManager.default.fileExists(atPath: newURL.path))
  }

  @Test
  func eventLogAppendsBatchInOrder() throws {
    let fileURL = FileManager.default.temporaryDirectory
      .appendingPathComponent("swiftweb-event-batch-\(UUID().uuidString).jsonl")
    defer {
      if FileManager.default.fileExists(atPath: fileURL.path) {
        do {
          try FileManager.default.removeItem(at: fileURL)
        } catch {
          Issue.record("Failed to clean event fixture: \(error)")
        }
      }
    }
    let eventLog = SwiftWebDevEventLog(fileURL: fileURL)
    let events = [
      SwiftWebDevEvent(kind: .clientBuildStarted, message: "start"),
      SwiftWebDevEvent(kind: .connected, message: "complete"),
    ]

    try eventLog.append(events)

    let stored = try eventLog.events(after: nil)
    #expect(stored.map(\.id) == events.map(\.id))
    #expect(stored.map(\.message) == ["start", "complete"])
  }

  @Test
  func publishedWasmGenerationSwitchesAllArtifactsAtomicallyAndRollsBack() throws {
    let directory = FileManager.default.temporaryDirectory
      .appendingPathComponent("swiftweb-published-wasm-test-\(UUID().uuidString)")
    try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    defer {
      do {
        try FileManager.default.removeItem(at: directory)
      } catch {
        Issue.record("Failed to clean published WASM fixture: \(error)")
      }
    }
    let configuration = SwiftWebDevRuntimeConfiguration(packageDirectory: directory)
    let firstSource = directory.appendingPathComponent("first-source.wasm")
    let secondSource = directory.appendingPathComponent("second-source.wasm")
    let runtimes = [
      SwiftWebGeneratedWasmRuntime(
        targetName: "FirstRuntime",
        productName: "first-runtime",
        componentTypeName: "First",
        assetPath: "/assets/first.wasm"
      ),
      SwiftWebGeneratedWasmRuntime(
        targetName: "SecondRuntime",
        productName: "second-runtime",
        componentTypeName: "Second",
        assetPath: "/assets/second.wasm"
      ),
    ]
    var sources = [
      "first-runtime": firstSource,
      "second-runtime": secondSource,
    ]
    try Data("first-v1".utf8).write(to: firstSource)
    try Data("second-v1".utf8).write(to: secondSource)

    let firstPublication = try SwiftWebDevPublishedWasmArtifacts.stage(
      runtimes: runtimes,
      contentHashesByProduct: [
        "first-runtime": "first-v1-hash",
        "second-runtime": "second-v1-hash",
      ],
      artifactURL: { try #require(sources[$0.productName]) },
      configuration: configuration
    )
    let current = SwiftWebDevPublishedWasmArtifacts.rootDirectory(for: configuration)
      .appendingPathComponent("current", isDirectory: true)
    #expect(!FileManager.default.fileExists(atPath: current.path))
    try firstPublication.commit()
    try firstPublication.finish()
    #expect(try Data(contentsOf: current.appendingPathComponent("first-runtime.wasm")) == Data("first-v1".utf8))
    #expect(try Data(contentsOf: current.appendingPathComponent("second-runtime.wasm")) == Data("second-v1".utf8))

    let replacementFirst = directory.appendingPathComponent("first-v2.wasm")
    let replacementSecond = directory.appendingPathComponent("second-v2.wasm")
    try Data("first-v2".utf8).write(to: replacementFirst)
    try Data("second-v2".utf8).write(to: replacementSecond)
    sources = [
      "first-runtime": replacementFirst,
      "second-runtime": replacementSecond,
    ]
    let secondPublication = try SwiftWebDevPublishedWasmArtifacts.stage(
      runtimes: runtimes,
      contentHashesByProduct: [
        "first-runtime": "first-v2-hash",
        "second-runtime": "second-v2-hash",
      ],
      artifactURL: { try #require(sources[$0.productName]) },
      configuration: configuration
    )
    #expect(try Data(contentsOf: current.appendingPathComponent("first-runtime.wasm")) == Data("first-v1".utf8))
    #expect(try Data(contentsOf: current.appendingPathComponent("second-runtime.wasm")) == Data("second-v1".utf8))
    try secondPublication.commit()
    #expect(try Data(contentsOf: current.appendingPathComponent("first-runtime.wasm")) == Data("first-v2".utf8))
    #expect(try Data(contentsOf: current.appendingPathComponent("second-runtime.wasm")) == Data("second-v2".utf8))
    let delayedFirstGenerationURL = try SwiftWebDevPublishedWasmArtifacts.resolveAsset(
      rootDirectory: SwiftWebDevPublishedWasmArtifacts.rootDirectory(for: configuration),
      generationID: firstPublication.generationID,
      productName: "first-runtime",
      requestedContentHash: "first-v1-hash"
    )
    let currentSecondGenerationURL = try SwiftWebDevPublishedWasmArtifacts.resolveAsset(
      rootDirectory: SwiftWebDevPublishedWasmArtifacts.rootDirectory(for: configuration),
      generationID: secondPublication.generationID,
      productName: "first-runtime",
      requestedContentHash: "first-v2-hash"
    )
    #expect(try Data(contentsOf: delayedFirstGenerationURL) == Data("first-v1".utf8))
    #expect(try Data(contentsOf: currentSecondGenerationURL) == Data("first-v2".utf8))
    try secondPublication.rollback()
    #expect(try Data(contentsOf: current.appendingPathComponent("first-runtime.wasm")) == Data("first-v1".utf8))
    #expect(try Data(contentsOf: current.appendingPathComponent("second-runtime.wasm")) == Data("second-v1".utf8))
  }

  @Test
  func publishedWasmGenerationsUseBoundedRetention() throws {
    let directory = FileManager.default.temporaryDirectory
      .appendingPathComponent("swiftweb-published-wasm-retention-test-\(UUID().uuidString)")
    try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    defer {
      do {
        try FileManager.default.removeItem(at: directory)
      } catch {
        Issue.record("Failed to clean published WASM retention fixture: \(error)")
      }
    }
    let configuration = SwiftWebDevRuntimeConfiguration(packageDirectory: directory)
    let source = directory.appendingPathComponent("runtime.wasm")
    let runtime = SwiftWebGeneratedWasmRuntime(
      targetName: "Runtime",
      productName: "runtime",
      componentTypeName: "Runtime",
      assetPath: "/assets/runtime.wasm"
    )

    for generation in 0..<(SwiftWebDevPublishedWasmArtifacts.retainedGenerationCount + 3) {
      try Data("generation-\(generation)".utf8).write(to: source)
      let publication = try SwiftWebDevPublishedWasmArtifacts.stage(
        runtimes: [runtime],
        contentHashesByProduct: ["runtime": "hash-\(generation)"],
        artifactURL: { _ in source },
        configuration: configuration
      )
      try publication.commit()
      try publication.finish()
    }

    let root = SwiftWebDevPublishedWasmArtifacts.rootDirectory(for: configuration)
    let generationCount = try FileManager.default.contentsOfDirectory(atPath: root.path)
      .filter { $0.hasPrefix("generation-") }
      .count
    #expect(generationCount == SwiftWebDevPublishedWasmArtifacts.retainedGenerationCount)
  }

  @Test
  func publishedWasmRetentionPreservesLiveWorkerLeaseThenCollectsIt() throws {
    let root = FileManager.default.temporaryDirectory
      .appendingPathComponent("swiftweb-published-wasm-lease-\(UUID().uuidString)")
    defer {
      if FileManager.default.fileExists(atPath: root.path) {
        do {
          try FileManager.default.removeItem(at: root)
        } catch {
          Issue.record("Failed to clean published WASM lease fixture: \(error)")
        }
      }
    }
    let configuration = SwiftWebDevRuntimeConfiguration(packageDirectory: root)
    let source = root.appendingPathComponent("runtime.wasm")
    try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
    try Data("initial".utf8).write(to: source)
    let runtime = SwiftWebGeneratedWasmRuntime(
      targetName: "Runtime",
      productName: "runtime",
      componentTypeName: "Runtime",
      assetPath: "/assets/runtime.wasm"
    )
    let firstPublication = try SwiftWebDevPublishedWasmArtifacts.stage(
      runtimes: [runtime],
      contentHashesByProduct: ["runtime": "hash-initial"],
      artifactURL: { _ in source },
      configuration: configuration
    )
    try firstPublication.commit()
    try firstPublication.finish()
    let publishedRoot = SwiftWebDevPublishedWasmArtifacts.rootDirectory(for: configuration)
    let leaseURL = try SwiftWebDevPublishedWasmArtifacts.acquireLease(
      rootDirectory: publishedRoot,
      generationID: firstPublication.generationID,
      processIdentifier: getpid()
    )

    for generation in 0..<(SwiftWebDevPublishedWasmArtifacts.retainedGenerationCount + 2) {
      try Data("generation-\(generation)".utf8).write(to: source)
      let publication = try SwiftWebDevPublishedWasmArtifacts.stage(
        runtimes: [runtime],
        contentHashesByProduct: ["runtime": "hash-\(generation)"],
        artifactURL: { _ in source },
        configuration: configuration
      )
      try publication.commit()
      try publication.finish()
    }

    let retainedWithLease = try FileManager.default.contentsOfDirectory(atPath: publishedRoot.path)
      .filter { $0.hasPrefix("generation-") }
      .count
    #expect(retainedWithLease == SwiftWebDevPublishedWasmArtifacts.retainedGenerationCount + 1)

    try FileManager.default.removeItem(at: leaseURL)
    try Data("final".utf8).write(to: source)
    let finalPublication = try SwiftWebDevPublishedWasmArtifacts.stage(
      runtimes: [runtime],
      contentHashesByProduct: ["runtime": "hash-final"],
      artifactURL: { _ in source },
      configuration: configuration
    )
    try finalPublication.commit()
    try finalPublication.finish()

    let retainedAfterRelease = try FileManager.default.contentsOfDirectory(atPath: publishedRoot.path)
      .filter { $0.hasPrefix("generation-") }
      .count
    #expect(retainedAfterRelease == SwiftWebDevPublishedWasmArtifacts.retainedGenerationCount)
  }

  @Test
  func boundedProcessKillsDescendantAfterLeaderExitsOnTermination() async throws {
    let childPIDURL = FileManager.default.temporaryDirectory
      .appendingPathComponent("swiftweb-descendant-pid-\(UUID().uuidString)")
    defer {
      if FileManager.default.fileExists(atPath: childPIDURL.path) {
        do {
          try FileManager.default.removeItem(at: childPIDURL)
        } catch {
          Issue.record("Failed to clean descendant PID fixture: \(error)")
        }
      }
    }
    let process = Process()
    process.executableURL = URL(fileURLWithPath: "/bin/sh")
    process.arguments = [
      "-c",
      "trap 'exit 0' TERM; (trap '' TERM; while :; do sleep 1; done) & echo $! > \"$1\"; wait",
      "swiftweb-descendant-fixture",
      childPIDURL.path,
    ]
    let clock = ContinuousClock()
    let started = clock.now

    do {
      _ = try await SwiftWebDevBoundedProcess.run(
        process,
        timeout: 0.2,
        terminationGracePeriod: 0.05,
        timeoutError: SwiftWebDevRuntimeError.buildTimedOut(
          command: "termination-resistant fixture",
          timeout: 0.2
        )
      )
      Issue.record("Expected the process to time out")
    } catch let error as SwiftWebDevRuntimeError {
      guard case .buildTimedOut = error else {
        Issue.record("Expected buildTimedOut, got \(error)")
        return
      }
    }

    #expect(!process.isRunning)
    #expect(started.duration(to: clock.now) < .seconds(2))
    let childPIDData = try Data(contentsOf: childPIDURL)
    let childPIDText = try #require(String(data: childPIDData, encoding: .utf8))
      .trimmingCharacters(in: .whitespacesAndNewlines)
    let childPID = try #require(Int32(childPIDText))
    let deadline = clock.now.advanced(by: .seconds(1))
    while kill(childPID, 0) == 0, clock.now < deadline {
      try await Task.sleep(for: .milliseconds(10))
    }
    #expect(kill(childPID, 0) != 0)
  }

  @Test
  func boundedProcessDrainsDescendantAfterSuccessfulLeaderExit() async throws {
    let childPIDURL = FileManager.default.temporaryDirectory
      .appendingPathComponent("swiftweb-success-descendant-pid-\(UUID().uuidString)")
    defer {
      if FileManager.default.fileExists(atPath: childPIDURL.path) {
        do {
          try FileManager.default.removeItem(at: childPIDURL)
        } catch {
          Issue.record("Failed to clean successful descendant PID fixture: \(error)")
        }
      }
    }
    let process = Process()
    process.executableURL = URL(fileURLWithPath: "/bin/sh")
    process.arguments = [
      "-c",
      "(trap '' TERM; while :; do sleep 1; done) & echo $! > \"$1\"; exit 0",
      "swiftweb-success-descendant-fixture",
      childPIDURL.path,
    ]

    let status = try await SwiftWebDevBoundedProcess.run(
      process,
      timeout: 5,
      terminationGracePeriod: 0.05,
      timeoutError: SwiftWebDevRuntimeError.buildTimedOut(
        command: "successful descendant fixture",
        timeout: 5
      )
    )

    #expect(status == 0)
    let childPIDData = try Data(contentsOf: childPIDURL)
    let childPIDText = try #require(String(data: childPIDData, encoding: .utf8))
      .trimmingCharacters(in: .whitespacesAndNewlines)
    let childPID = try #require(Int32(childPIDText))
    #expect(kill(childPID, 0) != 0)
  }

  @Test
  func cancellingDuringSuccessfulProcessGroupDrainPreservesCancellation() async throws {
    let childPIDURL = FileManager.default.temporaryDirectory
      .appendingPathComponent("swiftweb-drain-cancel-pid-\(UUID().uuidString)")
    defer {
      if FileManager.default.fileExists(atPath: childPIDURL.path) {
        do {
          try FileManager.default.removeItem(at: childPIDURL)
        } catch {
          Issue.record("Failed to clean drain cancellation PID fixture: \(error)")
        }
      }
    }
    let process = Process()
    process.executableURL = URL(fileURLWithPath: "/bin/sh")
    process.arguments = [
      "-c",
      "(trap '' TERM; while :; do sleep 1; done) & echo $! > \"$1\"; exit 0",
      "swiftweb-drain-cancel-fixture",
      childPIDURL.path,
    ]
    let task = Task {
      try await SwiftWebDevBoundedProcess.run(
        process,
        timeout: 5,
        terminationGracePeriod: 0.5,
        timeoutError: SwiftWebDevRuntimeError.buildTimedOut(
          command: "drain cancellation fixture",
          timeout: 5
        )
      )
    }
    defer { task.cancel() }
    let deadline = Date().addingTimeInterval(1)
    while Date() < deadline,
          (!FileManager.default.fileExists(atPath: childPIDURL.path) || process.isRunning) {
      try await Task.sleep(for: .milliseconds(5))
    }
    try #require(FileManager.default.fileExists(atPath: childPIDURL.path))
    #expect(!process.isRunning)
    task.cancel()

    do {
      _ = try await task.value
      Issue.record("Expected cancellation after process-group drain")
    } catch is CancellationError {
      // Expected after the uncancelled descendant cleanup completes.
    } catch {
      Issue.record("Expected CancellationError, got \(error)")
    }
    let childPIDData = try Data(contentsOf: childPIDURL)
    let childPIDText = try #require(String(data: childPIDData, encoding: .utf8))
      .trimmingCharacters(in: .whitespacesAndNewlines)
    let childPID = try #require(Int32(childPIDText))
    #expect(kill(childPID, 0) != 0)
  }

  @Test
  func cancellingBoundedProcessKillsDescendantAfterLeaderExits() async throws {
    let childPIDURL = FileManager.default.temporaryDirectory
      .appendingPathComponent("swiftweb-cancelled-descendant-pid-\(UUID().uuidString)")
    defer {
      if FileManager.default.fileExists(atPath: childPIDURL.path) {
        do {
          try FileManager.default.removeItem(at: childPIDURL)
        } catch {
          Issue.record("Failed to clean cancelled descendant PID fixture: \(error)")
        }
      }
    }
    let process = Process()
    process.executableURL = URL(fileURLWithPath: "/bin/sh")
    process.arguments = [
      "-c",
      "trap 'exit 0' TERM; (trap '' TERM; while :; do sleep 1; done) & echo $! > \"$1\"; wait",
      "swiftweb-cancelled-descendant-fixture",
      childPIDURL.path,
    ]
    let clock = ContinuousClock()
    let started = clock.now

    let task = Task {
      try await SwiftWebDevBoundedProcess.run(
        process,
        timeout: 60,
        terminationGracePeriod: 0.05,
        timeoutError: SwiftWebDevRuntimeError.buildTimedOut(
          command: "cancelled termination-resistant fixture",
          timeout: 60
        )
      )
    }
    defer {
      task.cancel()
    }
    let startupDeadline = clock.now.advanced(by: .seconds(1))
    while (!process.isRunning || !FileManager.default.fileExists(atPath: childPIDURL.path)),
          clock.now < startupDeadline {
      try await Task.sleep(for: .milliseconds(5))
    }
    try #require(FileManager.default.fileExists(atPath: childPIDURL.path))
    task.cancel()

    do {
      _ = try await task.value
      Issue.record("Expected the process task to be cancelled")
    } catch is CancellationError {
      // Expected cancellation after the child reaches a terminal state.
    } catch {
      Issue.record("Expected CancellationError, got \(error)")
    }

    #expect(!process.isRunning)
    #expect(started.duration(to: clock.now) < .seconds(2))
    let childPIDData = try Data(contentsOf: childPIDURL)
    let childPIDText = try #require(String(data: childPIDData, encoding: .utf8))
      .trimmingCharacters(in: .whitespacesAndNewlines)
    let childPID = try #require(Int32(childPIDText))
    #expect(kill(childPID, 0) != 0)
  }

  @Test
  func eventLogChunkReaderWaitsForWriterLock() async throws {
    let fileURL = FileManager.default.temporaryDirectory
      .appendingPathComponent("swiftweb-event-lock-\(UUID().uuidString).jsonl")
    try Data("complete\n".utf8).write(to: fileURL)
    defer {
      do {
        try FileManager.default.removeItem(at: fileURL)
      } catch {
        Issue.record("Failed to clean event lock fixture: \(error)")
      }
    }

    let descriptor = open(fileURL.path, O_RDWR)
    #expect(descriptor >= 0)
    guard descriptor >= 0 else {
      return
    }
    defer {
      close(descriptor)
    }
    #expect(flock(descriptor, LOCK_EX) == 0)

    let completed = Mutex(false)
    let readTask = Task {
      let data = try SwiftWebDevEventLogReader.fileChunkReader(fileURL, 0)
      completed.withLock { $0 = true }
      return data
    }
    try await Task.sleep(for: .milliseconds(50))
    #expect(!completed.withLock { $0 })
    #expect(flock(descriptor, LOCK_UN) == 0)

    let data = try await readTask.value
    #expect(data == Data("complete\n".utf8))
    #expect(completed.withLock { $0 })
  }
}
