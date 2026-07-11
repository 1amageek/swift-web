import SwiftWebDevelopmentHooks
import SwiftWebPackageGeneration
import SwiftWebWasmBuild
import CoreServices
import Foundation
import Synchronization

/// Produces snapshot diffs of the watched roots for the fast path (style and
/// WASM HMR). FSEvents marks pending work and forwards a wake hint; the
/// reconciler's fingerprint scan is the correctness path, so a missed event
/// here can only delay a fast-path patch, never lose a change
/// (docs/DevServerReconcilerDesign.md §4.6, §7).
final class SwiftWebDevFileChangeWatcher: Sendable {
    private let roots: [URL]
    private let snapshot: Mutex<SwiftWebDevFileSnapshot>
    private let pendingEvent: SwiftWebDevPendingEventFlag
    private let eventStream: SwiftWebDevFileEventStream?

    init(
        roots: [URL],
        usesFileEvents: Bool = true,
        onFileEvent: (@Sendable () -> Void)? = nil
    ) {
        let standardizedRoots = roots.map(\.standardizedFileURL)
        let pendingEvent = SwiftWebDevPendingEventFlag()
        self.roots = standardizedRoots
        self.snapshot = Mutex(SwiftWebDevFileSnapshot.capture(roots: standardizedRoots))
        self.pendingEvent = pendingEvent

        if usesFileEvents {
            let stream = SwiftWebDevFileEventStream(roots: standardizedRoots) {
                pendingEvent.raise()
                onFileEvent?()
            }
            self.eventStream = stream.start() ? stream : nil
        } else {
            self.eventStream = nil
        }
    }

    deinit {
        eventStream?.stop()
    }

    /// The changes since the previous call. With FSEvents active this is
    /// stat-free unless an event arrived; without FSEvents every call
    /// reconciles the snapshot.
    func changes() -> [SwiftWebDevFileChange] {
        if eventStream == nil {
            return reconcileSnapshot()
        }

        guard pendingEvent.consume() else {
            return []
        }

        return reconcileSnapshot()
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

private final class SwiftWebDevPendingEventFlag: Sendable {
    private let raised = Mutex(false)

    func raise() {
        raised.withLock { $0 = true }
    }

    func consume() -> Bool {
        raised.withLock { value in
            let output = value
            value = false
            return output
        }
    }
}

private final class SwiftWebDevFileEventStream: Sendable {
    private struct State {
        var streamAddress: UInt?
        var started = false
    }

    private let roots: [URL]
    private let onChange: @Sendable () -> Void
    private let queue = DispatchQueue(label: "codes.swiftweb.dev.file-events")
    private let queueKey = DispatchSpecificKey<Void>()
    private let state = Mutex(State())

    init(roots: [URL], onChange: @escaping @Sendable () -> Void) {
        self.roots = roots
        self.onChange = onChange
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

private struct SwiftWebDevFileSnapshotKey: Hashable {
    let rootPath: String
    let relativePath: String
}

private struct SwiftWebDevFileSnapshot: Equatable {
    let files: [SwiftWebDevFileSnapshotKey: SwiftWebDevFileStamp]

    static func capture(roots: [URL]) -> SwiftWebDevFileSnapshot {
        var files: [SwiftWebDevFileSnapshotKey: SwiftWebDevFileStamp] = [:]
        for root in roots {
            let rootPath = root.standardizedFileURL.path
            for (path, stamp) in captureRelativeStamps(root: root) {
                files[SwiftWebDevFileSnapshotKey(rootPath: rootPath, relativePath: path)] = stamp
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

    private static func change(
        for key: SwiftWebDevFileSnapshotKey,
        kind: SwiftWebDevFileChange.Kind
    ) -> SwiftWebDevFileChange {
        SwiftWebDevFileChange(
            path: key.relativePath,
            url: URL(fileURLWithPath: key.rootPath).appendingPathComponent(key.relativePath),
            kind: kind
        )
    }

    private static func captureRelativeStamps(root: URL) -> [String: SwiftWebDevFileStamp] {
        let fileManager = FileManager.default
        guard let enumerator = fileManager.enumerator(
            at: root,
            includingPropertiesForKeys: [.isDirectoryKey, .contentModificationDateKey, .fileSizeKey],
            options: []
        ) else {
            return [:]
        }

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
                    if SwiftWebDevWatchedFilePolicy.isExcludedDirectory(named: name) {
                        enumerator.skipDescendants()
                    }
                    continue
                }

                guard SwiftWebDevWatchedFilePolicy.isWatchedFile(url) else {
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

        return files
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
