import SwiftWebDevelopmentHooks
import SwiftWebPackageGeneration
import SwiftWebWasmBuild
import CoreServices
import Foundation
import Synchronization

final class SwiftWebDevFileChangeWatcher {
    private let roots: [URL]
    private let coalescingInterval: TimeInterval
    private let snapshot: Mutex<SwiftWebDevFileSnapshot>
    private let pendingEvent = Mutex(false)
    private let changeSignal = SwiftWebDevChangeSignal()
    private var eventStream: SwiftWebDevFileEventStream?

    init(
        roots: [URL],
        coalescingInterval: TimeInterval = 0.08,
        usesFileEvents: Bool = true
    ) {
        self.roots = roots.map(\.standardizedFileURL)
        self.coalescingInterval = max(coalescingInterval, 0)
        self.snapshot = Mutex(SwiftWebDevFileSnapshot.capture(roots: self.roots))

        if usesFileEvents {
            let stream = SwiftWebDevFileEventStream(roots: self.roots) { [weak self] in
                guard let self else {
                    return
                }
                pendingEvent.withLock { $0 = true }
                changeSignal.signal()
            }
            if stream.start() {
                self.eventStream = stream
            }
        }
    }

    deinit {
        eventStream?.stop()
    }

    func hasChanges() -> Bool {
        !changes().isEmpty
    }

    func changes() -> [SwiftWebDevFileChange] {
        if eventStream == nil {
            return reconcileSnapshot()
        }

        let hasPendingEvent = pendingEvent.withLock { value in
            let output = value
            value = false
            return output
        }

        guard hasPendingEvent else {
            return []
        }

        return reconcileSnapshot()
    }

    func waitForChanges(timeout: TimeInterval) -> Bool {
        !waitForChangeSet(timeout: timeout).isEmpty
    }

    func waitForChangeSet(timeout: TimeInterval) -> [SwiftWebDevFileChange] {
        if eventStream == nil {
            Thread.sleep(forTimeInterval: timeout)
            return coalescedChangeSet(startingWith: reconcileSnapshot())
        }

        let observedGeneration = changeSignal.currentGeneration()
        let immediateChanges = changes()
        if !immediateChanges.isEmpty {
            return coalescedChangeSet(startingWith: immediateChanges)
        }

        changeSignal.waitForChange(after: observedGeneration, timeout: timeout)
        return coalescedChangeSet(startingWith: changes())
    }

    func discardPendingChanges() {
        pendingEvent.withLock { $0 = false }
        let current = SwiftWebDevFileSnapshot.capture(roots: roots)
        snapshot.withLock { stored in
            stored = current
        }
    }

    private func reconcileSnapshot() -> [SwiftWebDevFileChange] {
        let current = SwiftWebDevFileSnapshot.capture(roots: roots)
        return snapshot.withLock { stored in
            guard current != stored else {
                return []
            }
            let changes = SwiftWebDevFileSnapshot.diff(from: stored, to: current)
            stored = current
            return changes
        }
    }

    private func coalescedChangeSet(
        startingWith initialChanges: [SwiftWebDevFileChange]
    ) -> [SwiftWebDevFileChange] {
        guard !initialChanges.isEmpty, coalescingInterval > 0 else {
            return SwiftWebDevFileChangeCoalescer.coalesce(initialChanges)
        }

        var changes = initialChanges
        var quietDeadline = Date().addingTimeInterval(coalescingInterval)
        while Date() < quietDeadline {
            let remaining = quietDeadline.timeIntervalSinceNow
            if remaining > 0 {
                if eventStream == nil {
                    Thread.sleep(forTimeInterval: remaining)
                } else {
                    let generation = changeSignal.currentGeneration()
                    changeSignal.waitForChange(after: generation, timeout: remaining)
                }
            }

            let nextChanges = self.changes()
            if !nextChanges.isEmpty {
                changes.append(contentsOf: nextChanges)
                quietDeadline = Date().addingTimeInterval(coalescingInterval)
            }
        }

        return SwiftWebDevFileChangeCoalescer.coalesce(changes)
    }
}

package struct SwiftWebDevFileChange: Sendable, Equatable {
    package let path: String
    package let url: URL
    package let kind: Kind

    package init(path: String, url: URL, kind: Kind) {
        self.path = path
        self.url = url
        self.kind = kind
    }

    package enum Kind: String, Sendable {
        case added
        case modified
        case removed
    }
}

private final class SwiftWebDevChangeSignal {
    private let condition = NSCondition()
    private var generation: UInt64 = 0

    func signal() {
        condition.lock()
        generation &+= 1
        condition.signal()
        condition.unlock()
    }

    func currentGeneration() -> UInt64 {
        condition.lock()
        let output = generation
        condition.unlock()
        return output
    }

    func waitForChange(after observedGeneration: UInt64, timeout: TimeInterval) {
        condition.lock()
        if generation == observedGeneration {
            condition.wait(until: Date().addingTimeInterval(timeout))
        }
        condition.unlock()
    }
}

private final class SwiftWebDevFileEventStream: NSObject {
    private struct State {
        var streamAddress: UInt?
        var started = false
    }

    private let roots: [URL]
    private let onChange: () -> Void
    private let queue = DispatchQueue(label: "codes.swiftweb.dev.file-events")
    private let queueKey = DispatchSpecificKey<Void>()
    private let state = Mutex(State())

    init(roots: [URL], onChange: @escaping () -> Void) {
        self.roots = roots
        self.onChange = onChange
        super.init()
        queue.setSpecific(key: queueKey, value: ())
    }

    func start() -> Bool {
        guard !roots.isEmpty else {
            return false
        }

        var context = FSEventStreamContext(
            version: 0,
            info: Unmanaged.passUnretained(self).toOpaque(),
            retain: nil,
            release: nil,
            copyDescription: nil
        )

        let paths = roots.map(\.path) as CFArray
        let flags = FSEventStreamCreateFlags(
            kFSEventStreamCreateFlagNoDefer |
            kFSEventStreamCreateFlagUseCFTypes |
            kFSEventStreamCreateFlagWatchRoot
        )

        guard let stream = FSEventStreamCreate(
            kCFAllocatorDefault,
            SwiftWebDevFileEventStream.handleEvents,
            &context,
            paths,
            FSEventStreamEventId(kFSEventStreamEventIdSinceNow),
            0.2,
            flags
        ) else {
            return false
        }

        FSEventStreamSetDispatchQueue(stream, queue)

        let didStart = FSEventStreamStart(stream)
        guard didStart else {
            FSEventStreamInvalidate(stream)
            FSEventStreamRelease(stream)
            return false
        }

        state.withLock {
            $0.streamAddress = UInt(bitPattern: stream)
            $0.started = true
        }
        return true
    }

    func stop() {
        let streamAddress = state.withLock { state in
            let streamAddress = state.streamAddress
            state.streamAddress = nil
            state.started = false
            return streamAddress
        }
        guard let streamAddress,
              let stream = OpaquePointer(bitPattern: streamAddress) else {
            return
        }

        let stopStream = {
            FSEventStreamStop(stream)
            FSEventStreamInvalidate(stream)
            FSEventStreamRelease(stream)
        }

        if DispatchQueue.getSpecific(key: queueKey) != nil {
            stopStream()
        } else {
            queue.sync(execute: stopStream)
        }
    }

    private static let handleEvents: FSEventStreamCallback = { _, info, eventCount, _, _, _ in
        guard let info, eventCount > 0 else {
            return
        }
        let stream = Unmanaged<SwiftWebDevFileEventStream>
            .fromOpaque(info)
            .takeUnretainedValue()
        stream.onChange()
    }
}

private struct SwiftWebDevFileSnapshot: Equatable {
    let files: [String: SwiftWebDevFileStamp]

    static func capture(roots: [URL]) -> SwiftWebDevFileSnapshot {
        var files: [String: SwiftWebDevFileStamp] = [:]
        for root in roots {
            let snapshot = capture(root: root)
            for (path, stamp) in snapshot.files {
                files["\(root.standardizedFileURL.path):\(path)"] = stamp
            }
        }
        return SwiftWebDevFileSnapshot(files: files)
    }

    static func diff(
        from old: SwiftWebDevFileSnapshot,
        to new: SwiftWebDevFileSnapshot
    ) -> [SwiftWebDevFileChange] {
        let oldKeys = Set(old.files.keys)
        let newKeys = Set(new.files.keys)
        var changes: [SwiftWebDevFileChange] = []

        for key in newKeys.subtracting(oldKeys) {
            changes.append(change(for: key, kind: .added))
        }

        for key in oldKeys.subtracting(newKeys) {
            changes.append(change(for: key, kind: .removed))
        }

        for key in oldKeys.intersection(newKeys) {
            guard old.files[key] != new.files[key] else {
                continue
            }
            changes.append(change(for: key, kind: .modified))
        }

        return changes.sorted { left, right in
            if left.path == right.path {
                return left.kind.rawValue < right.kind.rawValue
            }
            return left.path < right.path
        }
    }

    private static func change(for key: String, kind: SwiftWebDevFileChange.Kind) -> SwiftWebDevFileChange {
        let parts = key.split(separator: ":", maxSplits: 1, omittingEmptySubsequences: false)
        if parts.count == 2 {
            let root = String(parts[0])
            let relativePath = String(parts[1])
            return SwiftWebDevFileChange(
                path: relativePath,
                url: URL(fileURLWithPath: root).appendingPathComponent(relativePath),
                kind: kind
            )
        }

        return SwiftWebDevFileChange(
            path: key,
            url: URL(fileURLWithPath: key),
            kind: kind
        )
    }

    static func capture(root: URL) -> SwiftWebDevFileSnapshot {
        let fileManager = FileManager.default
        guard let enumerator = fileManager.enumerator(
            at: root,
            includingPropertiesForKeys: [.isDirectoryKey, .contentModificationDateKey, .fileSizeKey],
            options: []
        ) else {
            return SwiftWebDevFileSnapshot(files: [:])
        }

        let excludedDirectories: Set<String> = [
            ".build",
            ".git",
            ".swiftweb",
            ".swiftpm",
            "DerivedData",
        ]
        var files: [String: SwiftWebDevFileStamp] = [:]

        for case let url as URL in enumerator {
            let name = url.lastPathComponent
            do {
                let values = try url.resourceValues(forKeys: [
                    .isDirectoryKey,
                    .contentModificationDateKey,
                    .fileSizeKey,
                ])

                if values.isDirectory == true {
                    if excludedDirectories.contains(name) {
                        enumerator.skipDescendants()
                    }
                    continue
                }

                guard shouldWatch(url) else {
                    continue
                }

                let relativePath = relativePath(for: url, root: root)
                let modifiedAt = values.contentModificationDate?.timeIntervalSince1970 ?? 0
                let size = values.fileSize ?? 0
                files[relativePath] = SwiftWebDevFileStamp(modifiedAt: modifiedAt, size: size)
            } catch {
                continue
            }
        }

        return SwiftWebDevFileSnapshot(files: files)
    }

    private static func shouldWatch(_ url: URL) -> Bool {
        let name = url.lastPathComponent
        if name == "Package.swift" || name.hasSuffix(".swift") {
            return true
        }

        switch url.pathExtension {
        case "css", "json", "html", "leaf":
            return true
        default:
            return false
        }
    }

    private static func relativePath(for url: URL, root: URL) -> String {
        let rootPath = root.standardizedFileURL.path
        let path = url.standardizedFileURL.path
        guard path.hasPrefix(rootPath) else {
            return path
        }

        let index = path.index(path.startIndex, offsetBy: rootPath.count)
        return String(path[index...]).trimmingCharacters(in: CharacterSet(charactersIn: "/"))
    }
}

private struct SwiftWebDevFileStamp: Equatable {
    let modifiedAt: TimeInterval
    let size: Int
}
