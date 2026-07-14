import Foundation
import Synchronization
import Testing

@testable import SwiftWebDevelopmentHooks

@Suite
struct SwiftWebDevEventLogReaderTests {
  @Test
  func pollDeliversOnlyAppendedEvents() throws {
    let log = try makeLog()
    defer { removeLog(log) }
    let first = SwiftWebDevEvent(kind: .serverBuildStarted, message: "one")
    let second = SwiftWebDevEvent(kind: .serverRestarted, message: "two")
    try log.append(first)
    try log.append(second)

    let reader = try SwiftWebDevEventLogReader(log: log, after: first.id)

    let initial = try reader.poll()
    #expect(initial.map(\.id) == [second.id])

    let third = SwiftWebDevEvent(kind: .error, message: "three")
    try log.append(third)
    #expect(try reader.poll().map(\.id) == [third.id])
    #expect(try reader.poll().isEmpty)
  }

  @Test
  func pollNeverRereadsConsumedBytes() throws {
    let log = try makeLog()
    defer { removeLog(log) }
    for index in 0..<50 {
      try log.append(SwiftWebDevEvent(kind: .serverBuildStarted, message: "event-\(index)"))
    }

    let offsets = OffsetRecorder()
    let reader = try SwiftWebDevEventLogReader(
      log: log,
      after: nil,
      readChunk: offsets.recording(SwiftWebDevEventLogReader.fileChunkReader)
    )

    let all = try reader.poll()
    #expect(all.count == 50)
    let offsetAfterFirstPoll = reader.currentOffset
    #expect(offsetAfterFirstPoll > 0)

    try log.append(SwiftWebDevEvent(kind: .serverRestarted, message: "tail"))
    #expect(try reader.poll().count == 1)

    // The second data-bearing poll must start exactly where the first ended,
    // never back at zero.
    #expect(offsets.recorded.contains(offsetAfterFirstPoll))
    #expect(offsets.recorded.filter { $0 == 0 }.count == 1)
  }

  @Test
  func partialTrailingLineIsNotConsumedUntilComplete() throws {
    let log = try makeLog()
    defer { removeLog(log) }
    let event = SwiftWebDevEvent(kind: .serverRestarted, message: "whole")
    let encoded = try JSONEncoder.swiftWebDevEvent.encode(event)

    let reader = try SwiftWebDevEventLogReader(log: log, after: nil)

    // Writer got half a line out before the poll.
    let half = encoded.prefix(encoded.count / 2)
    let handle = try FileHandle(forWritingTo: log.fileURL)
    try handle.seekToEnd()
    try handle.write(contentsOf: half)
    #expect(try reader.poll().isEmpty)

    try handle.write(contentsOf: encoded.suffix(from: half.endIndex))
    try handle.write(contentsOf: Data([0x0A]))
    try handle.close()

    #expect(try reader.poll().map(\.id) == [event.id])
  }

  @Test
  func unknownResumeIDStaysSilentForBehaviorParity() throws {
    // Parity with SwiftWebDevEventLog.events(after:): an unknown resume ID
    // yields nothing. Real clients never reach this — the per-run dev token
    // rotation 401s and reloads them first.
    let log = try makeLog()
    defer { removeLog(log) }
    try log.append(SwiftWebDevEvent(kind: .serverRestarted, message: "existing"))

    let reader = try SwiftWebDevEventLogReader(log: log, after: "never-appended")

    try log.append(SwiftWebDevEvent(kind: .error, message: "later"))
    #expect(try reader.poll().isEmpty)
  }

  @Test
  func nilResumeDeliversFromStart() throws {
    let log = try makeLog()
    defer { removeLog(log) }
    let first = SwiftWebDevEvent(kind: .serverBuildStarted, message: "one")
    try log.append(first)

    let reader = try SwiftWebDevEventLogReader(log: log, after: nil)
    #expect(try reader.poll().map(\.id) == [first.id])
  }

  @Test
  func malformedCompletedLineFailsResumeScan() throws {
    let log = try makeLog()
    defer { removeLog(log) }
    let handle = try FileHandle(forWritingTo: log.fileURL)
    try handle.seekToEnd()
    try handle.write(contentsOf: Data("{malformed}\n".utf8))
    try handle.close()

    #expect(throws: DecodingError.self) {
      _ = try SwiftWebDevEventLogReader(log: log, after: "missing")
    }
  }

  // MARK: - Helpers

  private final class OffsetRecorder: Sendable {
    private let storage = Mutex<[UInt64]>([])

    var recorded: [UInt64] {
      storage.withLock { $0 }
    }

    func recording(
      _ base: @escaping SwiftWebDevEventLogReader.ChunkReader
    ) -> SwiftWebDevEventLogReader.ChunkReader {
      { fileURL, offset in
        self.storage.withLock { $0.append(offset) }
        return try base(fileURL, offset)
      }
    }
  }

  private func makeLog() throws -> SwiftWebDevEventLog {
    let fileURL = FileManager.default.temporaryDirectory
      .appendingPathComponent("SwiftWebDevEventLogReaderTests-\(UUID().uuidString)", isDirectory: true)
      .appendingPathComponent("hmr-events.jsonl")
    let log = SwiftWebDevEventLog(fileURL: fileURL)
    try log.reset()
    return log
  }

  private func removeLog(_ log: SwiftWebDevEventLog) {
    do {
      try FileManager.default.removeItem(at: log.fileURL.deletingLastPathComponent())
    } catch {
      Issue.record("Event log reader test cleanup failed: \(String(describing: error))")
    }
  }
}
