public protocol Page {
    var title: String { get async throws }
    var description: String? { get async throws }
    var language: String { get async throws }
    var cache: CachePolicy { get async throws }
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

    func metadata() async throws -> PageMetadata {
        PageMetadata(
            title: try await title,
            description: try await description,
            language: try await language
        )
    }
}
