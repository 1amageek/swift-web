import Foundation
import Synchronization
import Testing

@testable import SwiftWebDevelopmentHooks
@testable import SwiftWebDevServer

@Suite
struct SwiftWebDevReconcilerTests {
  private let fingerprintA = SwiftWebDevSourceFingerprint(digest: String(repeating: "a", count: 64), fileCount: 1)
  private let fingerprintB = SwiftWebDevSourceFingerprint(digest: String(repeating: "b", count: 64), fileCount: 1)

  @Test
  func editDuringInitialBuildTriggersFollowUpBuild() async throws {
    let world = World(initial: fingerprintA)
    let runTask = Task { await world.reconciler.run() }
    defer { world.reconciler.shutdown() }

    try await waitUntil("first build starts") { world.builder.startedCount == 1 }

    // The edit lands while the first build is still running — the exact
    // window the old pipeline silently discarded.
    world.fingerprinting.set(fingerprintB)
    world.reconciler.wake()

    world.builder.completeNext(with: URL(fileURLWithPath: "/tmp/exe-1"))
    try await waitUntil("second build starts") { world.builder.startedCount == 2 }
    #expect(world.recorder.queuedFingerprints.contains(fingerprintB))

    world.builder.completeNext(with: URL(fileURLWithPath: "/tmp/exe-2"))
    try await waitUntil("second worker serves") {
      await world.reconciler.snapshot().serving == self.fingerprintB
    }

    let snapshot = await world.reconciler.snapshot()
    #expect(snapshot.phase == .serving)
    #expect(!snapshot.isStale)
    #expect(world.launcher.launchCount == 2)
    // The first worker was replaced (blue/green), not abandoned.
    #expect(world.recorder.replacedFingerprints.last == fingerprintA)

    world.reconciler.shutdown()
    await runTask.value
  }

  @Test
  func buildFailureLatchesUntilSourcesChange() async throws {
    let world = World(initial: fingerprintA)
    let runTask = Task { await world.reconciler.run() }
    defer { world.reconciler.shutdown() }

    try await waitUntil("first build starts") { world.builder.startedCount == 1 }
    world.builder.failNext(with: SwiftWebDevRuntimeError.workerBuildFailed(
      command: "swift build",
      status: 1,
      firstErrorLine: "error: expected expression",
      logPath: "/tmp/build.log"
    ))

    try await waitUntil("failure latches") {
      await world.reconciler.snapshot().phase == .failed
    }

    // Waking again with unchanged sources must not hot-loop the broken tree.
    world.reconciler.wake()
    world.reconciler.wake()
    try await Task.sleep(nanoseconds: 200_000_000)
    #expect(world.builder.startedCount == 1)
    let failedSnapshot = await world.reconciler.snapshot()
    #expect(failedSnapshot.lastErrorSummary?.contains("expected expression") == true)

    // A source change clears the latch by construction.
    world.fingerprinting.set(fingerprintB)
    world.reconciler.wake()
    try await waitUntil("desired fingerprint updates") {
      await world.reconciler.snapshot().desired == self.fingerprintB
    }
    #expect(await world.reconciler.snapshot().phase == .building)
    try await waitUntil("retry build starts") { world.builder.startedCount == 2 }
    world.builder.completeNext(with: URL(fileURLWithPath: "/tmp/exe-2"))
    try await waitUntil("recovered worker serves") {
      await world.reconciler.snapshot().phase == .serving
    }
    #expect(await world.reconciler.snapshot().lastErrorSummary == nil)

    world.reconciler.shutdown()
    await runTask.value
  }

  @Test
  func crashRelaunchesFromExistingExecutableWithoutRebuild() async throws {
    let world = World(initial: fingerprintA)
    let runTask = Task { await world.reconciler.run() }
    defer { world.reconciler.shutdown() }

    try await serveInitialWorker(world, executablePath: "/tmp/exe-1")

    world.launcher.handle(at: 0).markExited(status: 9)

    try await waitUntil("crashed worker relaunches") { world.launcher.launchCount == 2 }
    try await waitUntil("relaunched worker serves") {
      await world.reconciler.snapshot().phase == .serving
    }

    // Relaunch reuses the built executable — the compiler never runs again.
    #expect(world.builder.startedCount == 1)
    #expect(world.launcher.launchRecord(at: 1).executable == world.launcher.launchRecord(at: 0).executable)
    #expect(world.recorder.crashes.first?.status == 9)
    #expect(world.recorder.crashes.first?.willRelaunch == true)
    #expect(await world.reconciler.snapshot().serving == fingerprintA)

    world.reconciler.shutdown()
    await runTask.value
  }

  @Test
  func crashLoopBreakerLatchesAfterRepeatedCrashes() async throws {
    let world = World(initial: fingerprintA, maxCrashCount: 3)
    let runTask = Task { await world.reconciler.run() }
    defer { world.reconciler.shutdown() }

    try await serveInitialWorker(world, executablePath: "/tmp/exe-1")

    world.launcher.handle(at: 0).markExited(status: 4)
    try await waitUntil("first relaunch") { world.launcher.launchCount == 2 }
    world.launcher.handle(at: 1).markExited(status: 4)
    try await waitUntil("second relaunch") { world.launcher.launchCount == 3 }
    world.launcher.handle(at: 2).markExited(status: 4)

    try await waitUntil("crash loop latches") {
      await world.reconciler.snapshot().phase == .failed
    }
    try await Task.sleep(nanoseconds: 200_000_000)
    #expect(world.launcher.launchCount == 3)
    #expect(world.builder.startedCount == 1)
    #expect(world.recorder.crashes.last?.willRelaunch == false)

    // Only a source change releases the latch.
    world.fingerprinting.set(fingerprintB)
    world.reconciler.wake()
    try await waitUntil("rebuild after latch") { world.builder.startedCount == 2 }
    world.builder.completeNext(with: URL(fileURLWithPath: "/tmp/exe-2"))
    try await waitUntil("recovered after crash latch") {
      await world.reconciler.snapshot().phase == .serving
    }

    world.reconciler.shutdown()
    await runTask.value
  }

  @Test
  func periodicTimerConvergesWithoutExplicitWake() async throws {
    // No wake() is ever sent for the change: only the timer backstop runs,
    // simulating a completely missed FSEvents delivery.
    let world = World(initial: fingerprintA, timerInterval: 0.05)
    let runTask = Task { await world.reconciler.run() }
    defer { world.reconciler.shutdown() }

    try await serveInitialWorker(world, executablePath: "/tmp/exe-1")

    world.fingerprinting.set(fingerprintB)

    try await waitUntil("timer-driven rebuild starts") { world.builder.startedCount == 2 }
    world.builder.completeNext(with: URL(fileURLWithPath: "/tmp/exe-2"))
    try await waitUntil("timer-driven worker serves") {
      await world.reconciler.snapshot().serving == self.fingerprintB
    }

    world.reconciler.shutdown()
    await runTask.value
  }

  @Test
  func unchangedSourcesNeverRebuild() async throws {
    let world = World(initial: fingerprintA)
    let runTask = Task { await world.reconciler.run() }
    defer { world.reconciler.shutdown() }

    try await serveInitialWorker(world, executablePath: "/tmp/exe-1")

    for _ in 0..<5 {
      world.reconciler.wake()
    }
    try await Task.sleep(nanoseconds: 200_000_000)

    #expect(world.builder.startedCount == 1)
    #expect(world.launcher.launchCount == 1)
    #expect(await world.reconciler.snapshot().phase == .serving)

    world.reconciler.shutdown()
    await runTask.value
  }

  @Test
  func shutdownCancelsInFlightBuildWithoutLaunchingWorker() async throws {
    let world = World(initial: fingerprintA)
    let runTask = Task { await world.reconciler.run() }

    try await waitUntil("initial build starts") { world.builder.startedCount == 1 }
    world.reconciler.shutdown()
    await runTask.value
    await world.reconciler.stopWorkerForShutdown()

    #expect(world.launcher.launchCount == 0)
    #expect(await world.reconciler.snapshot().serving == nil)
  }

  // MARK: - World

  private struct World {
    let fingerprinting: FakeFingerprinting
    let builder: FakeBuilder
    let launcher: FakeLauncher
    let recorder: ObserverRecorder
    let reconciler: SwiftWebDevReconciler

    init(
      initial: SwiftWebDevSourceFingerprint,
      timerInterval: TimeInterval = 60,
      maxCrashCount: Int = 3
    ) {
      let fingerprinting = FakeFingerprinting(initial)
      let builder = FakeBuilder()
      let launcher = FakeLauncher()
      let recorder = ObserverRecorder()
      self.fingerprinting = fingerprinting
      self.builder = builder
      self.launcher = launcher
      self.recorder = recorder
      self.reconciler = SwiftWebDevReconciler(
        fingerprinting: fingerprinting,
        builder: builder,
        launcher: launcher,
        observer: recorder.observer,
        timerInterval: timerInterval,
        maxCrashCount: maxCrashCount
      )
    }
  }

  private func serveInitialWorker(_ world: World, executablePath: String) async throws {
    try await waitUntil("initial build starts") { world.builder.startedCount == 1 }
    world.builder.completeNext(with: URL(fileURLWithPath: executablePath))
    try await waitUntil("initial worker serves") {
      await world.reconciler.snapshot().phase == .serving
    }
  }

  private func waitUntil(
    _ what: String,
    timeout: TimeInterval = 10,
    _ condition: @Sendable () async -> Bool
  ) async throws {
    let deadline = Date().addingTimeInterval(timeout)
    while Date() < deadline {
      if await condition() {
        return
      }
      try await Task.sleep(nanoseconds: 10_000_000)
    }
    Issue.record("Timed out waiting until \(what)")
    throw ReconcilerTestTimeout(what: what)
  }

  private struct ReconcilerTestTimeout: Error {
    let what: String
  }

  // MARK: - Fakes

  private final class FakeFingerprinting: SwiftWebDevSourceFingerprinting {
    private let current: Mutex<SwiftWebDevSourceFingerprint>

    init(_ initial: SwiftWebDevSourceFingerprint) {
      self.current = Mutex(initial)
    }

    func set(_ fingerprint: SwiftWebDevSourceFingerprint) {
      current.withLock { $0 = fingerprint }
    }

    func fingerprint() -> SwiftWebDevSourceFingerprint {
      current.withLock { $0 }
    }
  }

  private final class FakeBuilder: SwiftWebDevWorkerBuilding {
    private struct PendingBuild {
      let id: UUID
      let continuation: CheckedContinuation<URL, any Error>
    }

    private struct State {
      var pending: [PendingBuild] = []
      var cancelled: Set<UUID> = []
      var started = 0
    }

    private let state = Mutex(State())

    var startedCount: Int {
      state.withLock { $0.started }
    }

    func build(for fingerprint: SwiftWebDevSourceFingerprint) async throws -> URL {
      let id = UUID()
      return try await withTaskCancellationHandler {
        try Task.checkCancellation()
        return try await withCheckedThrowingContinuation { continuation in
          let wasCancelled = state.withLock { state in
            state.started += 1
            if state.cancelled.remove(id) != nil {
              return true
            }
            state.pending.append(PendingBuild(id: id, continuation: continuation))
            return false
          }
          if wasCancelled {
            continuation.resume(throwing: CancellationError())
          }
        }
      } onCancel: {
        let continuation: CheckedContinuation<URL, any Error>? = self.state.withLock { state in
          if let index = state.pending.firstIndex(where: { $0.id == id }) {
            return state.pending.remove(at: index).continuation
          }
          state.cancelled.insert(id)
          return nil
        }
        continuation?.resume(throwing: CancellationError())
      }
    }

    func completeNext(with url: URL) {
      let continuation = state.withLock { state in
        state.pending.isEmpty ? nil : state.pending.removeFirst().continuation
      }
      guard let continuation else {
        Issue.record("completeNext called with no pending build")
        return
      }
      continuation.resume(returning: url)
    }

    func failNext(with error: any Error) {
      let continuation = state.withLock { state in
        state.pending.isEmpty ? nil : state.pending.removeFirst().continuation
      }
      guard let continuation else {
        Issue.record("failNext called with no pending build")
        return
      }
      continuation.resume(throwing: error)
    }
  }

  private final class FakeLauncher: SwiftWebDevWorkerLaunching {
    struct LaunchRecord {
      let executable: URL
      let fingerprint: SwiftWebDevSourceFingerprint
    }

    private struct State {
      var records: [LaunchRecord] = []
      var handles: [SwiftWebDevWorkerHandle] = []
      var nextPort = 42000
    }

    private let state = Mutex(State())

    var launchCount: Int {
      state.withLock { $0.records.count }
    }

    func launchRecord(at index: Int) -> LaunchRecord {
      state.withLock { $0.records[index] }
    }

    func handle(at index: Int) -> SwiftWebDevWorkerHandle {
      state.withLock { $0.handles[index] }
    }

    func launch(
      executable: URL,
      fingerprint: SwiftWebDevSourceFingerprint
    ) async throws -> SwiftWebDevWorkerHandle {
      state.withLock { state in
        state.nextPort += 1
        let handle = SwiftWebDevWorkerHandle(
          target: SwiftWebDevWorkerTarget(host: "127.0.0.1", port: state.nextPort),
          fingerprint: fingerprint,
          executable: executable
        )
        state.records.append(LaunchRecord(executable: executable, fingerprint: fingerprint))
        state.handles.append(handle)
        return handle
      }
    }

    func waitReady(_ handle: SwiftWebDevWorkerHandle) async throws {}
  }

  private final class ObserverRecorder: Sendable {
    struct Crash {
      let status: Int32
      let willRelaunch: Bool
    }

    private struct State {
      var queued: [SwiftWebDevSourceFingerprint] = []
      var replaced: [SwiftWebDevSourceFingerprint] = []
      var crashes: [Crash] = []
    }

    private let state = Mutex(State())

    var queuedFingerprints: [SwiftWebDevSourceFingerprint] {
      state.withLock { $0.queued }
    }

    var replacedFingerprints: [SwiftWebDevSourceFingerprint] {
      state.withLock { $0.replaced }
    }

    var crashes: [Crash] {
      state.withLock { $0.crashes }
    }

    var observer: SwiftWebDevReconcilerObserver {
      var observer = SwiftWebDevReconcilerObserver()
      observer.changesQueuedDuringTransition = { fingerprint in
        self.state.withLock { $0.queued.append(fingerprint) }
      }
      observer.workerActivated = { _, previous in
        if let previous {
          self.state.withLock { $0.replaced.append(previous.fingerprint) }
        }
      }
      observer.workerCrashed = { status, willRelaunch in
        self.state.withLock { $0.crashes.append(Crash(status: status, willRelaunch: willRelaunch)) }
      }
      return observer
    }
  }
}
