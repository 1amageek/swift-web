import SwiftHTML
import Synchronization

/// Render-scoped document style state for one page response.
///
/// SwiftWeb binds one `DocumentStyle` per page render. During the render pass,
/// UI-layer code marks that it needs the document style bootstrap (root
/// stylesheet, head scripts, and root attributes) and records the page's
/// preferred color scheme. After the render, the page response encoder reads
/// this state to assemble the document.
///
/// The preferred color scheme uses SwiftUI presentation semantics: it applies
/// to the whole document regardless of where in the tree it was declared, and
/// later writers win.
public final class DocumentStyle: Sendable {
    private struct State {
        var bootstrapRequired = false
        var preference: DocumentColorSchemePreference?
    }
    private let state: Mutex<State>

    public init() {
        state = Mutex(State())
    }

    /// The render-scoped document state. Task-local for render isolation;
    /// `withCurrent(_:_:)` also installs an enlarged-stack propagator so
    /// SwiftHTML's dedicated render thread sees the same binding.
    @TaskLocal public static var current: DocumentStyle?

    @discardableResult
    public static func withCurrent<R>(_ document: DocumentStyle?, _ body: () throws -> R) rethrows -> R {
        try EnlargedStackContext.withValue(DocumentStyleContext(document: document)) {
            try $current.withValue(document, operation: body)
        }
    }

    /// Marks that this render used document-styled UI and therefore needs the
    /// bootstrap assets in the response document.
    public func requireBootstrap() {
        state.withLock { $0.bootstrapRequired = true }
    }

    public var bootstrapRequired: Bool {
        state.withLock { $0.bootstrapRequired }
    }

    /// Records the document's preferred color scheme. Later writers win. An
    /// explicit `nil` records "follow the user agent" and also wins over an
    /// earlier explicit scheme.
    public func recordPreferredColorScheme(_ rawValue: String?) {
        state.withLock { $0.preference = DocumentColorSchemePreference(rawValue: rawValue) }
    }

    public var preferredColorScheme: DocumentColorSchemePreference? {
        state.withLock { $0.preference }
    }
}

/// A recorded document color-scheme preference. `rawValue == nil` means the
/// page explicitly asked to follow the user agent preference.
public struct DocumentColorSchemePreference: Sendable, Equatable {
    public let rawValue: String?

    public init(rawValue: String?) {
        self.rawValue = rawValue
    }
}

private struct DocumentStyleContext: EnlargedStackContextPropagator {
    let document: DocumentStyle?

    func apply<Result>(_ operation: () throws -> Result) rethrows -> Result {
        try DocumentStyle.$current.withValue(document, operation: operation)
    }
}
