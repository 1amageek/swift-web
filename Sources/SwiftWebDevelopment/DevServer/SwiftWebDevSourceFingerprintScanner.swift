import CryptoKit
import Foundation
import Synchronization

/// Source of the `desired` fingerprint the reconciler converges on.
/// Abstracted so reconciler tests can move the source tree without touching
/// the filesystem (docs/DevServerReconcilerDesign.md §4, §12 T3).
package protocol SwiftWebDevSourceFingerprinting: Sendable {
    func fingerprint() -> SwiftWebDevSourceFingerprint
}

/// Computes the source-tree fingerprint the dev reconciler converges on.
/// Rescans are stat-only for unchanged files: content hashes are cached per
/// absolute path keyed by (modification time, size), so only files whose
/// stat stamp moved are re-read (docs/DevServerReconcilerDesign.md §3).
///
/// Known limitation, by design: a content change that preserves both the
/// nanosecond-resolution modification time and the size returns the cached
/// hash. On APFS this is not reachable in practice.
package final class SwiftWebDevSourceFingerprintScanner: SwiftWebDevSourceFingerprinting, Sendable {
    package typealias FileReader = @Sendable (URL) throws -> Data

    private struct CachedFileHash: Sendable {
        let modifiedAtNanoseconds: Int64
        let size: Int
        let contentHash: String
    }

    private let roots: [URL]
    private let readFile: FileReader
    /// Entries for deleted files linger until the process exits; the cache is
    /// bounded by the historical tree size of a dev session, which is fine.
    private let cache = Mutex<[String: CachedFileHash]>([:])

    package init(
        roots: [URL],
        readFile: @escaping FileReader = { url in try Data(contentsOf: url) }
    ) {
        self.roots = roots.map(\.standardizedFileURL)
        self.readFile = readFile
    }

    /// Walks every root and returns the tree fingerprint. Non-throwing: a
    /// file that vanishes or cannot be read mid-scan cannot be a build input,
    /// so it is treated as absent — the same policy the change watcher
    /// applies, keeping consecutive scans consistent with each other.
    package func fingerprint() -> SwiftWebDevSourceFingerprint {
        var manifestLines: [String] = []
        for root in roots {
            collectManifestLines(root: root, into: &manifestLines)
        }
        manifestLines.sort()

        var hasher = SHA256()
        for line in manifestLines {
            hasher.update(data: Data(line.utf8))
        }
        let digest = hasher.finalize().map { String(format: "%02x", $0) }.joined()
        return SwiftWebDevSourceFingerprint(digest: digest, fileCount: manifestLines.count)
    }

    private func collectManifestLines(root: URL, into lines: inout [String]) {
        guard let enumerator = FileManager.default.enumerator(
            at: root,
            includingPropertiesForKeys: [.isDirectoryKey, .contentModificationDateKey, .fileSizeKey],
            options: []
        ) else {
            return
        }

        for case let url as URL in enumerator {
            do {
                let values = try url.resourceValues(forKeys: [
                    .isDirectoryKey,
                    .contentModificationDateKey,
                    .fileSizeKey,
                ])

                if values.isDirectory == true {
                    if SwiftWebDevWatchedFilePolicy.isExcludedDirectory(named: url.lastPathComponent) {
                        enumerator.skipDescendants()
                    }
                    continue
                }

                guard SwiftWebDevWatchedFilePolicy.isWatchedFile(url) else {
                    continue
                }

                let path = url.standardizedFileURL.path
                let contentHash = try contentHash(for: url, path: path, values: values)
                lines.append("\(path)\u{0}\(contentHash)\n")
            } catch {
                continue
            }
        }
    }

    private func contentHash(
        for url: URL,
        path: String,
        values: URLResourceValues
    ) throws -> String {
        let modifiedAt = values.contentModificationDate ?? Date(timeIntervalSince1970: 0)
        let modifiedAtNanoseconds = Int64(modifiedAt.timeIntervalSince1970 * 1_000_000_000)
        let size = values.fileSize ?? 0

        if let cached = cache.withLock({ $0[path] }),
           cached.modifiedAtNanoseconds == modifiedAtNanoseconds,
           cached.size == size {
            return cached.contentHash
        }

        let data = try readFile(url)
        let contentHash = SHA256.hash(data: data)
            .map { String(format: "%02x", $0) }
            .joined()
        cache.withLock { entries in
            entries[path] = CachedFileHash(
                modifiedAtNanoseconds: modifiedAtNanoseconds,
                size: size,
                contentHash: contentHash
            )
        }
        return contentHash
    }
}
