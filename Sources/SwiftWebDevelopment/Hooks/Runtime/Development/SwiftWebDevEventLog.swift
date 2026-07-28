import Foundation

#if canImport(Darwin)
import Darwin
#elseif canImport(Glibc)
import Glibc
#endif

package struct SwiftWebDevEventLog: Sendable {
    package static let environmentKey = "SWIFT_WEB_DEV_EVENT_LOG"

    package let fileURL: URL

    package init(fileURL: URL) {
        self.fileURL = fileURL.standardizedFileURL
    }

    package init?(environment: [String: String] = ProcessInfo.processInfo.environment) {
        guard let path = environment[Self.environmentKey], !path.isEmpty else {
            return nil
        }
        self.init(fileURL: URL(fileURLWithPath: path))
    }

    package static func fileURL(for configuration: SwiftWebDevRuntimeConfiguration) -> URL {
        let root = configuration.scratchDirectory
            ?? configuration.packageDirectory
                .appendingPathComponent(".swiftweb", isDirectory: true)
                .appendingPathComponent("dev", isDirectory: true)
        return root
            .appendingPathComponent("hmr-events.jsonl")
            .standardizedFileURL
    }

    package func reset() throws {
        try FileManager.default.createDirectory(
            at: fileURL.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        try Data().write(to: fileURL, options: .atomic)
    }

    package func append(_ event: SwiftWebDevEvent) throws {
        try append([event])
    }

    /// Appends a logical event batch while holding one inter-process lock and
    /// issuing one file write, so readers observe either the old log or the
    /// complete batch.
    package func append(_ events: [SwiftWebDevEvent]) throws {
        guard !events.isEmpty else {
            return
        }
        try FileManager.default.createDirectory(
            at: fileURL.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        var batch = Data()
        for event in events {
            batch.append(try JSONEncoder.swiftWebDevEvent.encode(event))
            batch.append(0x0A)
        }

        let descriptor = open(fileURL.path, O_WRONLY | O_CREAT, S_IRUSR | S_IWUSR)
        guard descriptor >= 0 else {
            throw Self.posixError()
        }
        defer {
            close(descriptor)
        }

        guard flock(descriptor, LOCK_EX) == 0 else {
            throw Self.posixError()
        }
        defer {
            flock(descriptor, LOCK_UN)
        }

        let handle = FileHandle(fileDescriptor: descriptor, closeOnDealloc: false)
        try handle.seekToEnd()
        try handle.write(contentsOf: batch)
    }

    private static func posixError() -> POSIXError {
        POSIXError(POSIXErrorCode(rawValue: errno) ?? .EIO)
    }

    package func events(after id: String?) throws -> [SwiftWebDevEvent] {
        guard FileManager.default.fileExists(atPath: fileURL.path) else {
            return []
        }

        let data = try lockedData()
        guard !data.isEmpty else {
            return []
        }

        let text = String(decoding: data, as: UTF8.self)
        var events: [SwiftWebDevEvent] = []
        for line in text.split(separator: "\n") {
            let data = Data(String(line).utf8)
            events.append(try JSONDecoder.swiftWebDevEvent.decode(SwiftWebDevEvent.self, from: data))
        }

        guard let id else {
            return events
        }
        guard let index = events.lastIndex(where: { $0.id == id }) else {
            return []
        }
        return Array(events[events.index(after: index)...])
    }

    package func latestEventID() throws -> String? {
        try events(after: nil).last?.id
    }

    private func lockedData() throws -> Data {
        let descriptor = open(fileURL.path, O_RDONLY)
        guard descriptor >= 0 else {
            throw Self.posixError()
        }
        defer {
            close(descriptor)
        }
        guard flock(descriptor, LOCK_SH) == 0 else {
            throw Self.posixError()
        }
        defer {
            flock(descriptor, LOCK_UN)
        }
        let handle = FileHandle(fileDescriptor: descriptor, closeOnDealloc: false)
        return try handle.readToEnd() ?? Data()
    }
}

extension JSONEncoder {
    package static var swiftWebDevEvent: JSONEncoder {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        return encoder
    }
}

extension JSONDecoder {
    package static var swiftWebDevEvent: JSONDecoder {
        JSONDecoder()
    }
}
