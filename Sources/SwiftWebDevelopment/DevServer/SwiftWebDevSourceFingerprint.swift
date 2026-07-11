import Foundation

/// Content identity of the watched source tree: a SHA-256 digest over the
/// sorted (path, content-hash) manifest of every watched file. Equal
/// fingerprints mean the trees are byte-identical for build purposes, so a
/// `touch` that leaves content unchanged does not change the fingerprint
/// (docs/DevServerReconcilerDesign.md §3).
package struct SwiftWebDevSourceFingerprint: Sendable, Hashable, CustomStringConvertible {
    /// Full SHA-256 hex over the manifest. Equality uses this.
    package let digest: String
    package let fileCount: Int

    package init(digest: String, fileCount: Int) {
        self.digest = digest
        self.fileCount = fileCount
    }

    /// Display form used in logs, response headers, and status payloads.
    package var short: String {
        String(digest.prefix(12))
    }

    package var description: String {
        short
    }
}
