import Foundation

struct SwiftWebAdapterManifest: Codable, Equatable, Sendable {
    struct Defaults: Codable, Equatable, Sendable {
        let host: String?
        let deployment: String?
    }

    struct Template: Codable, Equatable, Sendable {
        let source: String
        let destination: String

        init(source: String, destination: String = "") {
            self.source = source
            self.destination = destination
        }

        init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            source = try container.decode(String.self, forKey: .source)
            destination = try container.decodeIfPresent(String.self, forKey: .destination) ?? ""
        }
    }

    struct Host: Codable, Equatable, Sendable {
        let produces: [String]
        let templates: [Template]
        let variables: [String: String]
        let operations: [String: [SwiftWebLifecycleTask]]

        init(
            produces: [String],
            templates: [Template] = [],
            variables: [String: String] = [:],
            operations: [String: [SwiftWebLifecycleTask]] = [:]
        ) {
            self.produces = produces
            self.templates = templates
            self.variables = variables
            self.operations = operations
        }

        init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            produces = try container.decode([String].self, forKey: .produces)
            templates = try container.decodeIfPresent([Template].self, forKey: .templates) ?? []
            variables = try container.decodeIfPresent([String: String].self, forKey: .variables) ?? [:]
            operations = try container.decodeIfPresent(
                [String: [SwiftWebLifecycleTask]].self,
                forKey: .operations
            ) ?? [:]
        }
    }

    struct Deployment: Codable, Equatable, Sendable {
        let accepts: [String]
        let produces: [String]
        let templates: [Template]
        let variables: [String: String]
        let operations: [String: [SwiftWebLifecycleTask]]

        init(
            accepts: [String],
            produces: [String] = [],
            templates: [Template] = [],
            variables: [String: String] = [:],
            operations: [String: [SwiftWebLifecycleTask]] = [:]
        ) {
            self.accepts = accepts
            self.produces = produces
            self.templates = templates
            self.variables = variables
            self.operations = operations
        }

        init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            accepts = try container.decode([String].self, forKey: .accepts)
            produces = try container.decodeIfPresent([String].self, forKey: .produces) ?? []
            templates = try container.decodeIfPresent([Template].self, forKey: .templates) ?? []
            variables = try container.decodeIfPresent([String: String].self, forKey: .variables) ?? [:]
            operations = try container.decodeIfPresent(
                [String: [SwiftWebLifecycleTask]].self,
                forKey: .operations
            ) ?? [:]
        }
    }

    let schemaVersion: Int
    let kind: String
    let id: String
    let defaults: Defaults
    let hosts: [String: Host]
    let deployments: [String: Deployment]
}
