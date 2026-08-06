import Foundation

struct SwiftWebLifecycleTask: Codable, Equatable, Sendable {
    enum Kind: String, Codable, Sendable {
        case command
        case prepareApplication
        case buildServer
        case buildBrowserRuntime
        case runDevelopmentServer
    }

    enum Stage: String, Codable, Sendable {
        case beforeHost
        case afterHost
        case beforeDeployment
        case afterDeployment
    }

    let id: String
    let kind: Kind
    let stage: Stage?
    let executable: String?
    let arguments: [String]
    let workingDirectory: String?
    let environment: [String: String]
    let dependsOn: [String]
    let inputs: [String]
    let outputs: [String]

    init(
        id: String,
        kind: Kind,
        stage: Stage? = nil,
        executable: String? = nil,
        arguments: [String] = [],
        workingDirectory: String? = nil,
        environment: [String: String] = [:],
        dependsOn: [String] = [],
        inputs: [String] = [],
        outputs: [String] = []
    ) {
        self.id = id
        self.kind = kind
        self.stage = stage
        self.executable = executable
        self.arguments = arguments
        self.workingDirectory = workingDirectory
        self.environment = environment
        self.dependsOn = dependsOn
        self.inputs = inputs
        self.outputs = outputs
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(String.self, forKey: .id)
        kind = try container.decode(Kind.self, forKey: .kind)
        stage = try container.decodeIfPresent(Stage.self, forKey: .stage)
        executable = try container.decodeIfPresent(String.self, forKey: .executable)
        arguments = try container.decodeIfPresent([String].self, forKey: .arguments) ?? []
        workingDirectory = try container.decodeIfPresent(String.self, forKey: .workingDirectory)
        environment = try container.decodeIfPresent([String: String].self, forKey: .environment) ?? [:]
        dependsOn = try container.decodeIfPresent([String].self, forKey: .dependsOn) ?? []
        inputs = try container.decodeIfPresent([String].self, forKey: .inputs) ?? []
        outputs = try container.decodeIfPresent([String].self, forKey: .outputs) ?? []
    }
}
