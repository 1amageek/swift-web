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
        case beforeService
        case afterService
        case beforeHost
        case afterHost
        case beforeDeployment
        case afterDeployment
    }

    enum Lifetime: String, Codable, Sendable {
        case finite
        case persistent
    }

    let id: String
    let kind: Kind
    let lifetime: Lifetime
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
        lifetime: Lifetime = .finite,
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
        self.lifetime = lifetime
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
        lifetime = try container.decodeIfPresent(Lifetime.self, forKey: .lifetime) ?? .finite
        stage = try container.decodeIfPresent(Stage.self, forKey: .stage)
        executable = try container.decodeIfPresent(String.self, forKey: .executable)
        arguments = try container.decodeIfPresent([String].self, forKey: .arguments) ?? []
        workingDirectory = try container.decodeIfPresent(String.self, forKey: .workingDirectory)
        environment = try container.decodeIfPresent([String: String].self, forKey: .environment) ?? [:]
        dependsOn = try container.decodeIfPresent([String].self, forKey: .dependsOn) ?? []
        inputs = try container.decodeIfPresent([String].self, forKey: .inputs) ?? []
        outputs = try container.decodeIfPresent([String].self, forKey: .outputs) ?? []
    }

    func scoped(to service: String) -> SwiftWebLifecycleTask {
        SwiftWebLifecycleTask(
            id: "service.\(service).\(id)",
            kind: kind,
            lifetime: lifetime,
            stage: stage,
            executable: executable.map { scopedValue($0, service: service) },
            arguments: arguments.map { scopedValue($0, service: service) },
            workingDirectory: scopedPath(workingDirectory, service: service),
            environment: environment.mapValues { scopedValue($0, service: service) },
            dependsOn: dependsOn.map { "service.\(service).\($0)" },
            inputs: inputs.map { scopedPath($0, service: service) },
            outputs: outputs.map { scopedPath($0, service: service) }
        )
    }

    private func scopedValue(_ value: String, service: String) -> String {
        value.replacingOccurrences(
            of: "{{service.",
            with: "{{services.\(service)."
        )
    }

    private func scopedPath(_ path: String?, service: String) -> String? {
        let serviceWorkspace = "{{services.\(service).workspace}}"
        guard let path else {
            return serviceWorkspace
        }
        let rendered = scopedValue(path, service: service)
        guard !rendered.hasPrefix("/"),
            !usesAbsoluteRootPlaceholder(
                rendered,
                service: service,
                serviceWorkspace: serviceWorkspace
            )
        else {
            return rendered
        }
        return rendered.isEmpty ? serviceWorkspace : "\(serviceWorkspace)/\(rendered)"
    }

    private func scopedPath(_ path: String, service: String) -> String {
        scopedPath(Optional(path), service: service) ?? "{{services.\(service).workspace}}"
    }

    private func usesAbsoluteRootPlaceholder(
        _ path: String,
        service: String,
        serviceWorkspace: String
    ) -> Bool {
        let fixedRoots = [
            serviceWorkspace,
            "{{services.\(service).adapter.root}}",
            "{{project.root}}",
            "{{generated.root}}",
            "{{workspace.root}}",
        ]
        if fixedRoots.contains(where: { path == $0 || path.hasPrefix($0 + "/") }) {
            return true
        }
        guard path.hasPrefix("{{adapter."),
            let closingRange = path.range(of: "}}")
        else {
            return false
        }
        let suffix = path[closingRange.upperBound...]
        guard suffix.isEmpty || suffix.hasPrefix("/") else {
            return false
        }
        let placeholder = path[..<closingRange.lowerBound]
        return placeholder.hasSuffix(".root")
    }
}
