public protocol Page {
    var title: String { get async throws }
    var description: String? { get async throws }
    var language: String { get async throws }
    var cache: CachePolicy { get async throws }
    /// A class applied to the document `<body>`. Default is none; a page opts into
    /// a body-level surface (e.g. a full-viewport app shell) by returning a class
    /// the SwiftWebUI root styles.
    var bodyClass: String? { get async throws }
}

public extension Page {
    var title: String {
        get async throws {
            String(describing: Self.self)
        }
    }

    var description: String? {
        get async throws {
            nil
        }
    }

    var language: String {
        get async throws {
            "en"
        }
    }

    var cache: CachePolicy {
        get async throws {
            .none
        }
    }

    var bodyClass: String? {
        get async throws {
            nil
        }
    }

    func metadata() async throws -> PageMetadata {
        PageMetadata(
            title: try await title,
            description: try await description,
            language: try await language,
            bodyClass: try await bodyClass
        )
    }
}
