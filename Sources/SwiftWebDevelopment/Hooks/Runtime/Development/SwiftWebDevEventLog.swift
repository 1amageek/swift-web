import Foundation

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
        try FileManager.default.createDirectory(
            at: fileURL.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        let data = try JSONEncoder.swiftWebDevEvent.encode(event)
        var line = data
        line.append(0x0A)

        if !FileManager.default.fileExists(atPath: fileURL.path) {
            try Data().write(to: fileURL, options: .atomic)
        }

        let handle = try FileHandle(forWritingTo: fileURL)
        defer {
            handle.closeFile()
        }
        try handle.seekToEnd()
        try handle.write(contentsOf: line)
    }

    package func events(after id: String?) throws -> [SwiftWebDevEvent] {
        guard FileManager.default.fileExists(atPath: fileURL.path) else {
            return []
        }

        let data = try Data(contentsOf: fileURL)
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
