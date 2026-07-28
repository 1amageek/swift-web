import SwiftHTML

/// A route that resolves to a complete HTML document.
///
/// Use ``StaticPage`` for direct document production and ``LoadedPage`` when
/// rendering depends on an asynchronously loaded model.
public protocol Page {
    associatedtype Document: HTMLDocument

    var cache: CachePolicy { get async throws }
    func resolveDocument() async throws -> Document
}

public extension Page {
    var cache: CachePolicy {
        get async throws {
            EnvironmentValues.current.pageCachePolicy
        }
    }
}

/// A page whose document can be produced directly.
public protocol StaticPage: Page where Document: HTMLDocument {
    associatedtype Document

    var document: Document { get }
}

public extension StaticPage {
    func resolveDocument() async throws -> Document {
        document
    }
}

/// A page that loads a model before producing its document.
public protocol LoadedPage: Page where Document: HTMLDocument {
    associatedtype Model: Sendable
    associatedtype Document

    func load() async throws -> Model

    func document(_ model: Model) -> Document
}

public extension LoadedPage {
    func resolveDocument() async throws -> Document {
        let model = try await load()
        return document(model)
    }
}
