import Foundation
import Synchronization

/// Incremental reader over the HMR event JSONL file. Each SSE stream owns one
/// reader; polls decode only bytes appended since the previous poll instead
/// of re-reading and re-decoding the whole log every 300 ms
/// (docs/DevServerReconcilerDesign.md §8).
///
/// Behavior parity with `SwiftWebDevEventLog.events(after:)` is preserved:
/// a resume ID that never appears in the log yields no events. Real clients
/// never hit that path — the dev token rotates per server run and a token
/// mismatch reloads the page before resuming.
package final class SwiftWebDevEventLogReader: Sendable {
    /// Reads bytes from `offset` to the current end of file. Injectable so
    /// tests can assert polls never re-read consumed bytes.
    package typealias ChunkReader = @Sendable (_ fileURL: URL, _ offset: UInt64) throws -> Data

    private struct State {
        var offset: UInt64
        var neverMatched: Bool
    }

    private let fileURL: URL
    private let readChunk: ChunkReader
    private let state: Mutex<State>

    package init(
        log: SwiftWebDevEventLog,
        after lastEventID: String?,
        readChunk: @escaping ChunkReader = SwiftWebDevEventLogReader.fileChunkReader
    ) throws {
        self.fileURL = log.fileURL
        self.readChunk = readChunk

        guard let lastEventID else {
            self.state = Mutex(State(offset: 0, neverMatched: false))
            return
        }

        // One full scan at connect time locates the resume point; every poll
        // afterwards reads appended bytes only.
        let data = try readChunk(log.fileURL, 0)
        var resumeOffset: UInt64?
        var lineStart = data.startIndex
        while lineStart < data.endIndex {
            guard let newlineIndex = data[lineStart...].firstIndex(of: 0x0A) else {
                break
            }
            let line = data[lineStart..<newlineIndex]
            if let event = try? JSONDecoder.swiftWebDevEvent.decode(
                SwiftWebDevEvent.self,
                from: Data(line)
            ), event.id == lastEventID {
                resumeOffset = UInt64(newlineIndex - data.startIndex) + 1
            }
            lineStart = data.index(after: newlineIndex)
        }

        if let resumeOffset {
            self.state = Mutex(State(offset: resumeOffset, neverMatched: false))
        } else {
            self.state = Mutex(State(offset: 0, neverMatched: true))
        }
    }

    /// Returns the events appended since the previous poll. A trailing line
    /// without its newline is left unconsumed until the writer completes it.
    package func poll() throws -> [SwiftWebDevEvent] {
        let (offset, neverMatched) = state.withLock { ($0.offset, $0.neverMatched) }
        guard !neverMatched else {
            return []
        }

        let data = try readChunk(fileURL, offset)
        guard !data.isEmpty else {
            return []
        }

        var events: [SwiftWebDevEvent] = []
        var consumed: UInt64 = 0
        var lineStart = data.startIndex
        while lineStart < data.endIndex {
            guard let newlineIndex = data[lineStart...].firstIndex(of: 0x0A) else {
                break
            }
            let line = data[lineStart..<newlineIndex]
            if !line.isEmpty {
                events.append(
                    try JSONDecoder.swiftWebDevEvent.decode(SwiftWebDevEvent.self, from: Data(line))
                )
            }
            consumed = UInt64(newlineIndex - data.startIndex) + 1
            lineStart = data.index(after: newlineIndex)
        }

        if consumed > 0 {
            state.withLock { $0.offset = offset + consumed }
        }
        return events
    }

    package var currentOffset: UInt64 {
        state.withLock { $0.offset }
    }

    package static let fileChunkReader: ChunkReader = { fileURL, offset in
        guard FileManager.default.fileExists(atPath: fileURL.path) else {
            return Data()
        }
        let handle = try FileHandle(forReadingFrom: fileURL)
        defer {
            do {
                try handle.close()
            } catch {
                // Closing a read-only handle cannot lose data; nothing to
                // surface beyond the read result itself.
            }
        }
        try handle.seek(toOffset: offset)
        return try handle.readToEnd() ?? Data()
    }
}
