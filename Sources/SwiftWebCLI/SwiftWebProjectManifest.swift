import Foundation

struct SwiftWebProjectManifest: Codable, Equatable, Sendable {
    struct Application: Codable, Equatable, Sendable {
        let product: String
        let module: String?
        let type: String
    }

    struct Defaults: Codable, Equatable, Sendable {
        let build: String?
        let dev: String?
        let deploy: String?
    }

    struct Overlay: Codable, Equatable, Sendable {
        let source: String
        let destination: String
        let excluding: [String]

        init(source: String, destination: String = "", excluding: [String] = []) {
            self.source = source
            self.destination = destination
            self.excluding = excluding
        }

        init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            source = try container.decode(String.self, forKey: .source)
            destination = try container.decodeIfPresent(String.self, forKey: .destination) ?? ""
            excluding = try container.decodeIfPresent([String].self, forKey: .excluding) ?? []
        }
    }

    struct Environment: Codable, Equatable, Sendable {
        let host: String
        let deployment: String
        let overlays: [Overlay]
        let operations: [String: [SwiftWebLifecycleTask]]

        init(
            host: String,
            deployment: String,
            overlays: [Overlay] = [],
            operations: [String: [SwiftWebLifecycleTask]] = [:]
        ) {
            self.host = host
            self.deployment = deployment
            self.overlays = overlays
            self.operations = operations
        }

        init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            host = try container.decode(String.self, forKey: .host)
            deployment = try container.decode(String.self, forKey: .deployment)
            overlays = try container.decodeIfPresent([Overlay].self, forKey: .overlays) ?? []
            operations = try container.decodeIfPresent(
                [String: [SwiftWebLifecycleTask]].self,
                forKey: .operations
            ) ?? [:]
        }
    }

    let schemaVersion: Int
    let application: Application
    let environments: [String: Environment]
    let defaults: Defaults
}
