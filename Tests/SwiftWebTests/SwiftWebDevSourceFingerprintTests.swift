import Foundation
import Synchronization
import Testing

@testable import SwiftWebDevServer

@Suite
struct SwiftWebDevSourceFingerprintTests {
  @Test
  func fingerprintIsDeterministicAcrossScannerInstances() throws {
    let root = try makeTemporaryRoot()
    defer { removeTemporaryRoot(root) }
    try write("struct A {}", to: root.appendingPathComponent("Sources/App/A.swift"))
    try write(".a { color: red; }", to: root.appendingPathComponent("Sources/App/A.css"))
    try write("// package", to: root.appendingPathComponent("Package.swift"))

    let first = SwiftWebDevSourceFingerprintScanner(roots: [root]).fingerprint()
    let second = SwiftWebDevSourceFingerprintScanner(roots: [root]).fingerprint()
    let rescan = SwiftWebDevSourceFingerprintScanner(roots: [root]).fingerprint()

    #expect(first == second)
    #expect(first == rescan)
    #expect(first.fileCount == 3)
    #expect(first.digest.count == 64)
    #expect(first.short == String(first.digest.prefix(12)))
  }

  @Test
  func fingerprintIsIndependentOfRootOrder() throws {
    let firstRoot = try makeTemporaryRoot()
    defer { removeTemporaryRoot(firstRoot) }
    let secondRoot = try makeTemporaryRoot()
    defer { removeTemporaryRoot(secondRoot) }
    try write("struct A {}", to: firstRoot.appendingPathComponent("A.swift"))
    try write("struct B {}", to: secondRoot.appendingPathComponent("B.swift"))

    let forward = SwiftWebDevSourceFingerprintScanner(roots: [firstRoot, secondRoot]).fingerprint()
    let reversed = SwiftWebDevSourceFingerprintScanner(roots: [secondRoot, firstRoot]).fingerprint()

    #expect(forward == reversed)
    #expect(forward.fileCount == 2)
  }

  @Test
  func includesPackageAndSourceInputsWhileExcludingBuildProducts() throws {
    let root = try makeTemporaryRoot()
    defer { removeTemporaryRoot(root) }
    try write("struct A {}", to: root.appendingPathComponent("Sources/App/A.swift"))

    let scanner = SwiftWebDevSourceFingerprintScanner(roots: [root])
    let before = scanner.fingerprint()

    // Package pins and arbitrary files under Sources are valid SwiftPM inputs.
    try write("{}", to: root.appendingPathComponent("Package.resolved"))
    try write("binary", to: root.appendingPathComponent("Sources/App/logo.png"))
    let withInputs = scanner.fingerprint()

    #expect(before != withInputs)
    #expect(withInputs.fileCount == 3)

    // Generated and repository metadata must not move the fingerprint.
    try write("built", to: root.appendingPathComponent(".build/module.swift"))
    try write("ref", to: root.appendingPathComponent(".git/config.json"))
    try write("gen", to: root.appendingPathComponent(".swiftweb/generated/Package.swift"))
    try write("pin", to: root.appendingPathComponent(".swiftpm/state.json"))
    try write("cache", to: root.appendingPathComponent("DerivedData/index.json"))

    let after = scanner.fingerprint()

    #expect(withInputs == after)
  }

  @Test
  func touchWithSameContentKeepsFingerprint() throws {
    let root = try makeTemporaryRoot()
    defer { removeTemporaryRoot(root) }
    let file = root.appendingPathComponent("Sources/App/A.swift")
    try write("struct A {}", to: file)

    let reads = ReadCounter()
    let scanner = SwiftWebDevSourceFingerprintScanner(roots: [root], readFile: reads.reader)
    let before = scanner.fingerprint()
    let readsBefore = reads.count

    try write("struct A {}", to: file)
    try bumpModificationDate(of: file)
    let after = scanner.fingerprint()

    // The stamp moved, so the file must be re-read — and the fingerprint must
    // still be identical because the content is.
    #expect(reads.count > readsBefore)
    #expect(before == after)
  }

  @Test
  func contentChangeChangesFingerprint() throws {
    let root = try makeTemporaryRoot()
    defer { removeTemporaryRoot(root) }
    let file = root.appendingPathComponent("Sources/App/A.swift")
    try write("struct A {}", to: file)

    let scanner = SwiftWebDevSourceFingerprintScanner(roots: [root])
    let before = scanner.fingerprint()

    // Same byte count as the original so the change is only visible to the
    // content hash, never to the (mtime, size) stamp alone.
    try write("struct B {}", to: file)
    try bumpModificationDate(of: file)
    let after = scanner.fingerprint()

    #expect(before != after)
    #expect(before.fileCount == after.fileCount)
  }

  @Test
  func unchangedRescanIsStatOnly() throws {
    let root = try makeTemporaryRoot()
    defer { removeTemporaryRoot(root) }
    try write("struct A {}", to: root.appendingPathComponent("Sources/App/A.swift"))
    try write(".a {}", to: root.appendingPathComponent("Sources/App/A.css"))

    let reads = ReadCounter()
    let scanner = SwiftWebDevSourceFingerprintScanner(roots: [root], readFile: reads.reader)

    let first = scanner.fingerprint()
    let readsAfterFirstScan = reads.count
    #expect(readsAfterFirstScan == 2)

    let second = scanner.fingerprint()

    #expect(first == second)
    #expect(reads.count == readsAfterFirstScan)
  }

  @Test
  func watchedFilePolicyMatchesWatchedSet() {
    #expect(SwiftWebDevWatchedFilePolicy.isWatchedFile(fileURL("Package.swift")))
    #expect(SwiftWebDevWatchedFilePolicy.isWatchedFile(fileURL("Package.resolved")))
    #expect(SwiftWebDevWatchedFilePolicy.isWatchedFile(fileURL("Sources/App/A.swift")))
    #expect(SwiftWebDevWatchedFilePolicy.isWatchedFile(fileURL("Sources/App/A.css")))
    #expect(SwiftWebDevWatchedFilePolicy.isWatchedFile(fileURL("Sources/App/data.json")))
    #expect(SwiftWebDevWatchedFilePolicy.isWatchedFile(fileURL("Sources/App/page.html")))
    #expect(SwiftWebDevWatchedFilePolicy.isWatchedFile(fileURL("Sources/App/page.leaf")))

    #expect(SwiftWebDevWatchedFilePolicy.isWatchedFile(fileURL("Sources/App/logo.png")))
    #expect(SwiftWebDevWatchedFilePolicy.isWatchedFile(fileURL("Sources/CLib/include/module.modulemap")))
    #expect(SwiftWebDevWatchedFilePolicy.isWatchedFile(fileURL("Plugins/BuildPlugin/config.bin")))
    #expect(!SwiftWebDevWatchedFilePolicy.isWatchedFile(fileURL("README.md")))

    #expect(SwiftWebDevWatchedFilePolicy.isExcludedDirectory(named: ".build"))
    #expect(SwiftWebDevWatchedFilePolicy.isExcludedDirectory(named: ".git"))
    #expect(SwiftWebDevWatchedFilePolicy.isExcludedDirectory(named: ".swiftweb"))
    #expect(SwiftWebDevWatchedFilePolicy.isExcludedDirectory(named: ".swiftpm"))
    #expect(SwiftWebDevWatchedFilePolicy.isExcludedDirectory(named: "DerivedData"))
    #expect(!SwiftWebDevWatchedFilePolicy.isExcludedDirectory(named: "Sources"))
  }

  // MARK: - Helpers

  private final class ReadCounter: Sendable {
    private let storage = Mutex(0)

    var count: Int {
      storage.withLock { $0 }
    }

    var reader: SwiftWebDevSourceFingerprintScanner.FileReader {
      { url in
        self.record()
        return try Data(contentsOf: url)
      }
    }

    private func record() {
      storage.withLock { $0 += 1 }
    }
  }

  private func makeTemporaryRoot() throws -> URL {
    let root = FileManager.default.temporaryDirectory
      .appendingPathComponent("SwiftWebDevSourceFingerprintTests-\(UUID().uuidString)", isDirectory: true)
    try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
    return root
  }

  private func removeTemporaryRoot(_ root: URL) {
    do {
      try FileManager.default.removeItem(at: root)
    } catch {
      Issue.record("Fingerprint test cleanup failed: \(String(describing: error))")
    }
  }

  private func write(_ content: String, to url: URL) throws {
    try FileManager.default.createDirectory(
      at: url.deletingLastPathComponent(),
      withIntermediateDirectories: true
    )
    try content.write(to: url, atomically: true, encoding: .utf8)
  }

  /// Guarantees the stat stamp moves even when a rewrite lands within the
  /// filesystem timestamp granularity of the original write.
  private func bumpModificationDate(of url: URL) throws {
    try FileManager.default.setAttributes(
      [.modificationDate: Date().addingTimeInterval(5)],
      ofItemAtPath: url.path
    )
  }

  private func fileURL(_ path: String) -> URL {
    URL(fileURLWithPath: "/tmp/fingerprint-policy/\(path)")
  }
}
