import Foundation
import Synchronization
import Testing

@testable import SwiftWebDevelopmentHooks
@testable import SwiftWebDevServer

@Suite
struct SwiftWebDevWorkerLauncherTests {
  @Test
  func launchPassesBuildFingerprintAndDevEnvironment() async throws {
    let root = try makeTemporaryRoot()
    defer { removeTemporaryRoot(root) }
    // The fake worker dumps its environment next to itself, then idles until
    // the test stops it.
    let executable = root.appendingPathComponent("fake-worker")
    let capturedEnvironment = root.appendingPathComponent("captured-env.txt")
    try makeExecutable(
      at: executable,
      script: """
      #!/bin/sh
      env > "\(capturedEnvironment.path)"
      exec /bin/sleep 30
      """
    )

    let fingerprint = SwiftWebDevSourceFingerprint(digest: String(repeating: "ab", count: 32), fileCount: 3)
    let launcher = SwiftWebDevWorkerLauncher(
      configuration: configuration(packageDirectory: root),
      devToken: "test-token"
    )

    let handle = try await launcher.launch(executable: executable, fingerprint: fingerprint)
    defer { Task { await handle.stop() } }

    let environment = try await waitForFile(at: capturedEnvironment)
    #expect(environment.contains("SWIFT_WEB_DEV_BUILD_FINGERPRINT=\(fingerprint.digest)"))
    #expect(environment.contains("SWIFT_WEB_DEV=1"))
    #expect(environment.contains("SWIFT_WEB_DEV_RELOAD_TOKEN=test-token"))
    #expect(handle.fingerprint == fingerprint)
    #expect(handle.target.host == "127.0.0.1")
    #expect(handle.target.port > 0)
    #expect(handle.isRunning)

    await handle.stop()
    #expect(!handle.isRunning)
  }

  @Test
  func terminationObserverFiresAndLateRegistrationFiresImmediately() async throws {
    let root = try makeTemporaryRoot()
    defer { removeTemporaryRoot(root) }
    let executable = root.appendingPathComponent("fake-worker")
    try makeExecutable(at: executable, script: "#!/bin/sh\nexit 7\n")

    let launcher = SwiftWebDevWorkerLauncher(
      configuration: configuration(packageDirectory: root),
      devToken: "test-token"
    )
    let handle = try await launcher.launch(
      executable: executable,
      fingerprint: SwiftWebDevSourceFingerprint(digest: "cafe", fileCount: 0)
    )

    let observed = try await withCheckedThrowingContinuation { continuation in
      handle.onTermination { status in
        continuation.resume(returning: status)
      }
    }
    #expect(observed == 7)
    #expect(handle.terminationStatus == 7)
    #expect(!handle.isRunning)

    // Registration after exit must fire immediately, not never.
    let lateObserved = Mutex<Int32?>(nil)
    handle.onTermination { status in
      lateObserved.withLock { $0 = status }
    }
    #expect(lateObserved.withLock { $0 } == 7)
  }

  @Test
  func waitReadySurfacesEarlyWorkerExit() async throws {
    let root = try makeTemporaryRoot()
    defer { removeTemporaryRoot(root) }
    let executable = root.appendingPathComponent("fake-worker")
    try makeExecutable(at: executable, script: "#!/bin/sh\nexit 4\n")

    let launcher = SwiftWebDevWorkerLauncher(
      configuration: configuration(packageDirectory: root),
      devToken: "test-token"
    )
    let handle = try await launcher.launch(
      executable: executable,
      fingerprint: SwiftWebDevSourceFingerprint(digest: "dead", fileCount: 0)
    )

    let started = Date()
    await #expect(throws: SwiftWebDevRuntimeError.self) {
      try await launcher.waitReady(handle)
    }
    // Early exit must be reported well before the readiness timeout burns.
    #expect(Date().timeIntervalSince(started) < 2)
  }

  // MARK: - Helpers

  private func configuration(packageDirectory: URL) -> SwiftWebDevRuntimeConfiguration {
    SwiftWebDevRuntimeConfiguration(
      packageDirectory: packageDirectory,
      scratchDirectory: packageDirectory.appendingPathComponent("scratch", isDirectory: true),
      product: "fake-worker",
      readinessTimeout: 5
    )
  }

  private func waitForFile(at url: URL, timeout: TimeInterval = 5) async throws -> String {
    let deadline = Date().addingTimeInterval(timeout)
    while Date() < deadline {
      if let data = FileManager.default.contents(atPath: url.path),
         !data.isEmpty {
        return String(decoding: data, as: UTF8.self)
      }
      try await Task.sleep(nanoseconds: 50_000_000)
    }
    Issue.record("Fake worker never wrote \(url.path)")
    return ""
  }

  private func makeTemporaryRoot() throws -> URL {
    let root = FileManager.default.temporaryDirectory
      .appendingPathComponent("SwiftWebDevWorkerLauncherTests-\(UUID().uuidString)", isDirectory: true)
    try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
    return root
  }

  private func removeTemporaryRoot(_ root: URL) {
    do {
      try FileManager.default.removeItem(at: root)
    } catch {
      Issue.record("Worker launcher test cleanup failed: \(String(describing: error))")
    }
  }

  private func makeExecutable(at url: URL, script: String) throws {
    try FileManager.default.createDirectory(
      at: url.deletingLastPathComponent(),
      withIntermediateDirectories: true
    )
    try script.write(to: url, atomically: true, encoding: .utf8)
    try FileManager.default.setAttributes(
      [.posixPermissions: 0o755],
      ofItemAtPath: url.path
    )
  }
}
