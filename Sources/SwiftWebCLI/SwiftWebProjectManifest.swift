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
        let services: [String]
        let overlays: [Overlay]
        let operations: [String: [SwiftWebLifecycleTask]]

        init(
            host: String,
            deployment: String,
            services: [String] = [],
            overlays: [Overlay] = [],
            operations: [String: [SwiftWebLifecycleTask]] = [:]
        ) {
            self.host = host
            self.deployment = deployment
            self.services = services
            self.overlays = overlays
            self.operations = operations
        }

        init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            host = try container.decode(String.self, forKey: .host)
            deployment = try container.decode(String.self, forKey: .deployment)
            services = try container.decodeIfPresent([String].self, forKey: .services) ?? []
            overlays = try container.decodeIfPresent([Overlay].self, forKey: .overlays) ?? []
            operations =
                try container.decodeIfPresent(
                    [String: [SwiftWebLifecycleTask]].self,
                    forKey: .operations
                ) ?? [:]
        }
    }

    struct Service: Codable, Equatable, Sendable {
        struct Actor: Codable, Equatable, Sendable {
            let product: String
            let module: String?
            let type: String

            private enum CodingKeys: String, CodingKey {
                case product
                case module
                case type
                case identity
            }

            init(
                product: String,
                module: String? = nil,
                type: String
            ) {
                self.product = product
                self.module = module
                self.type = type
            }

            init(from decoder: Decoder) throws {
                let container = try decoder.container(keyedBy: CodingKeys.self)
                if container.contains(.identity) {
                    throw DecodingError.dataCorruptedError(
                        forKey: .identity,
                        in: container,
                        debugDescription:
                            "Actor identity belongs to the Swift .actor(_:identity:) modifier"
                    )
                }
                product = try container.decode(String.self, forKey: .product)
                module = try container.decodeIfPresent(String.self, forKey: .module)
                type = try container.decode(String.self, forKey: .type)
            }

            func encode(to encoder: Encoder) throws {
                var container = encoder.container(keyedBy: CodingKeys.self)
                try container.encode(product, forKey: .product)
                try container.encodeIfPresent(module, forKey: .module)
                try container.encode(type, forKey: .type)
            }
        }

        let application: Application
        let adapter: String
        let adapterTraits: [String]
        let dependsOn: [String]
        let actors: [Actor]
        let variables: [String: String]
        let overlays: [Overlay]
        let operations: [String: [SwiftWebLifecycleTask]]

        init(
            application: Application,
            adapter: String,
            adapterTraits: [String] = [],
            dependsOn: [String] = [],
            actors: [Actor] = [],
            variables: [String: String] = [:],
            overlays: [Overlay] = [],
            operations: [String: [SwiftWebLifecycleTask]] = [:]
        ) {
            self.application = application
            self.adapter = adapter
            self.adapterTraits = adapterTraits
            self.dependsOn = dependsOn
            self.actors = actors
            self.variables = variables
            self.overlays = overlays
            self.operations = operations
        }

        init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            application = try container.decode(Application.self, forKey: .application)
            adapter = try container.decode(String.self, forKey: .adapter)
            adapterTraits =
                try container.decodeIfPresent(
                    [String].self,
                    forKey: .adapterTraits
                ) ?? []
            dependsOn = try container.decodeIfPresent([String].self, forKey: .dependsOn) ?? []
            actors = try container.decodeIfPresent([Actor].self, forKey: .actors) ?? []
            variables =
                try container.decodeIfPresent(
                    [String: String].self,
                    forKey: .variables
                ) ?? [:]
            overlays = try container.decodeIfPresent([Overlay].self, forKey: .overlays) ?? []
            operations =
                try container.decodeIfPresent(
                    [String: [SwiftWebLifecycleTask]].self,
                    forKey: .operations
                ) ?? [:]
        }
    }

    let schemaVersion: Int
    let application: Application
    let services: [String: Service]
    let environments: [String: Environment]
    let defaults: Defaults

    init(
        schemaVersion: Int,
        application: Application,
        services: [String: Service] = [:],
        environments: [String: Environment],
        defaults: Defaults
    ) {
        self.schemaVersion = schemaVersion
        self.application = application
        self.services = services
        self.environments = environments
        self.defaults = defaults
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        schemaVersion = try container.decode(Int.self, forKey: .schemaVersion)
        application = try container.decode(Application.self, forKey: .application)
        services = try container.decodeIfPresent([String: Service].self, forKey: .services) ?? [:]
        environments = try container.decode([String: Environment].self, forKey: .environments)
        defaults = try container.decode(Defaults.self, forKey: .defaults)
    }
}
