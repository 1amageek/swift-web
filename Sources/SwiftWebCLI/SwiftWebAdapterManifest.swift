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
            operations =
                try container.decodeIfPresent(
                    [String: [SwiftWebLifecycleTask]].self,
                    forKey: .operations
                ) ?? [:]
        }
    }

    struct Deployment: Codable, Equatable, Sendable {
        struct ActorBinding: Codable, Equatable, Sendable {
            private enum CodingKeys: String, CodingKey {
                case hostRoute
                case clientRoute
                case configuration
                case swiftExpression
            }

            struct Route: Codable, Equatable, Sendable {
                let transport: String
                let endpointPrefix: String
                let endpointSuffix: String

                init(
                    transport: String,
                    endpointPrefix: String,
                    endpointSuffix: String = ""
                ) {
                    self.transport = transport
                    self.endpointPrefix = endpointPrefix
                    self.endpointSuffix = endpointSuffix
                }

                init(from decoder: Decoder) throws {
                    let container = try decoder.container(keyedBy: CodingKeys.self)
                    transport = try container.decode(String.self, forKey: .transport)
                    endpointPrefix = try container.decode(String.self, forKey: .endpointPrefix)
                    endpointSuffix = try container.decodeIfPresent(
                        String.self,
                        forKey: .endpointSuffix
                    ) ?? ""
                }
            }

            let hostRoute: Route
            let clientRoute: Route?
            let configuration: [String: String]

            init(
                hostRoute: Route,
                clientRoute: Route? = nil,
                configuration: [String: String] = [:]
            ) {
                self.hostRoute = hostRoute
                self.clientRoute = clientRoute
                self.configuration = configuration
            }

            init(from decoder: Decoder) throws {
                let container = try decoder.container(keyedBy: CodingKeys.self)
                if container.contains(.swiftExpression) {
                    throw DecodingError.dataCorruptedError(
                        forKey: .swiftExpression,
                        in: container,
                        debugDescription:
                            "Actor bindings accept structured routes, not Swift source expressions"
                    )
                }
                hostRoute = try container.decode(Route.self, forKey: .hostRoute)
                clientRoute = try container.decodeIfPresent(Route.self, forKey: .clientRoute)
                configuration = try container.decodeIfPresent(
                    [String: String].self,
                    forKey: .configuration
                ) ?? [:]
            }

            func encode(to encoder: Encoder) throws {
                var container = encoder.container(keyedBy: CodingKeys.self)
                try container.encode(hostRoute, forKey: .hostRoute)
                try container.encodeIfPresent(clientRoute, forKey: .clientRoute)
                if !configuration.isEmpty {
                    try container.encode(configuration, forKey: .configuration)
                }
            }
        }

        let accepts: [String]
        let acceptsServiceArtifacts: [String]
        let actorBindings: [String: ActorBinding]
        let produces: [String]
        let templates: [Template]
        let variables: [String: String]
        let operations: [String: [SwiftWebLifecycleTask]]

        init(
            accepts: [String],
            acceptsServiceArtifacts: [String] = [],
            actorBindings: [String: ActorBinding] = [:],
            produces: [String] = [],
            templates: [Template] = [],
            variables: [String: String] = [:],
            operations: [String: [SwiftWebLifecycleTask]] = [:]
        ) {
            self.accepts = accepts
            self.acceptsServiceArtifacts = acceptsServiceArtifacts
            self.actorBindings = actorBindings
            self.produces = produces
            self.templates = templates
            self.variables = variables
            self.operations = operations
        }

        init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            accepts = try container.decode([String].self, forKey: .accepts)
            acceptsServiceArtifacts =
                try container.decodeIfPresent(
                    [String].self,
                    forKey: .acceptsServiceArtifacts
                ) ?? []
            actorBindings =
                try container.decodeIfPresent(
                    [String: ActorBinding].self,
                    forKey: .actorBindings
                ) ?? [:]
            produces = try container.decodeIfPresent([String].self, forKey: .produces) ?? []
            templates = try container.decodeIfPresent([Template].self, forKey: .templates) ?? []
            variables = try container.decodeIfPresent([String: String].self, forKey: .variables) ?? [:]
            operations =
                try container.decodeIfPresent(
                    [String: [SwiftWebLifecycleTask]].self,
                    forKey: .operations
                ) ?? [:]
        }
    }

    struct Service: Codable, Equatable, Sendable {
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
            variables =
                try container.decodeIfPresent(
                    [String: String].self,
                    forKey: .variables
                ) ?? [:]
            operations =
                try container.decodeIfPresent(
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
    let services: [String: Service]

    init(
        schemaVersion: Int,
        kind: String,
        id: String,
        defaults: Defaults,
        hosts: [String: Host],
        deployments: [String: Deployment],
        services: [String: Service] = [:]
    ) {
        self.schemaVersion = schemaVersion
        self.kind = kind
        self.id = id
        self.defaults = defaults
        self.hosts = hosts
        self.deployments = deployments
        self.services = services
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        schemaVersion = try container.decode(Int.self, forKey: .schemaVersion)
        kind = try container.decode(String.self, forKey: .kind)
        id = try container.decode(String.self, forKey: .id)
        defaults = try container.decode(Defaults.self, forKey: .defaults)
        hosts = try container.decodeIfPresent([String: Host].self, forKey: .hosts) ?? [:]
        deployments =
            try container.decodeIfPresent(
                [String: Deployment].self,
                forKey: .deployments
            ) ?? [:]
        services = try container.decodeIfPresent([String: Service].self, forKey: .services) ?? [:]
    }
}
