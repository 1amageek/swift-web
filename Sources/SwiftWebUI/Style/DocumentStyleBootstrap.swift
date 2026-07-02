import Synchronization

/// Supplies the document-level style bootstrap: the root stylesheet, head
/// scripts, and the root attributes applied to the document `<body>`.
///
/// The UI layer installs one provider per process; the page response encoder
/// consults it when a render marked `DocumentStyle.requireBootstrap()`.
public protocol DocumentStyleBootstrapProvider: Sendable {
    /// The document root stylesheet, emitted through the base style channel.
    var stylesheet: String { get }
    /// Head scripts required by the document styles, keyed by stable id.
    var scripts: [DocumentStyleScript] { get }
    /// The class added to `<body>` so root-scoped selectors apply.
    var rootClass: String { get }
    /// The style-system identifier emitted as `data-style-system` on `<body>`.
    var styleSystemID: String { get }
}

public struct DocumentStyleScript: Sendable {
    public let id: String
    public let body: String

    public init(id: String, body: String) {
        self.id = id
        self.body = body
    }
}

/// Process-global registration point for the document style bootstrap.
/// Installation is idempotent: the first installed provider wins so one
/// deterministic document style serves the whole process.
public enum DocumentStyleBootstrap {
    private static let state = Mutex<(any DocumentStyleBootstrapProvider)?>(nil)

    public static func install(_ provider: any DocumentStyleBootstrapProvider) {
        state.withLock { current in
            if current == nil {
                current = provider
            }
        }
    }

    public static var installed: (any DocumentStyleBootstrapProvider)? {
        state.withLock { $0 }
    }
}
