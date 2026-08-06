import Foundation

struct SwiftWebProjectResolution: Sendable {
    struct Adapter: Sendable {
        let package: SwiftPackageDependencyGraph.Package
        let directory: URL
        let manifest: SwiftWebAdapterManifest
    }

    struct Environment: Sendable {
        let name: String
        let project: SwiftWebProjectManifest.Environment
        let hostAdapter: Adapter
        let hostName: String
        let host: SwiftWebAdapterManifest.Host
        let deploymentAdapter: Adapter
        let deploymentName: String
        let deployment: SwiftWebAdapterManifest.Deployment
    }

    let packageDirectory: URL
    let package: SwiftPackageDependencyGraph.Package
    let manifest: SwiftWebProjectManifest
    let adapters: [String: Adapter]

    func environment(named name: String) throws -> Environment {
        guard let projectEnvironment = manifest.environments[name] else {
            throw SwiftWebLifecycleError.environmentNotFound(name)
        }
        let hostSelection = try resolveHost(projectEnvironment.host)
        let deploymentSelection = try resolveDeployment(projectEnvironment.deployment)
        let producedArtifacts = Set(hostSelection.component.produces)
        let acceptedArtifacts = Set(deploymentSelection.component.accepts)
        guard !producedArtifacts.isDisjoint(with: acceptedArtifacts) else {
            throw SwiftWebLifecycleError.incompatibleArtifacts(
                host: hostSelection.component.produces,
                deployment: deploymentSelection.component.accepts
            )
        }
        return Environment(
            name: name,
            project: projectEnvironment,
            hostAdapter: hostSelection.adapter,
            hostName: hostSelection.name,
            host: hostSelection.component,
            deploymentAdapter: deploymentSelection.adapter,
            deploymentName: deploymentSelection.name,
            deployment: deploymentSelection.component
        )
    }

    private func resolveHost(
        _ selector: String
    ) throws -> (adapter: Adapter, name: String, component: SwiftWebAdapterManifest.Host) {
        let selection = try componentSelection(selector)
        guard let adapter = adapters[selection.adapter] else {
            throw SwiftWebLifecycleError.adapterNotFound(selection.adapter)
        }
        let name = try selection.component ?? adapter.manifest.defaults.host.unwrap(
            or: SwiftWebLifecycleError.hostNotFound(adapter: selection.adapter, host: "default")
        )
        guard let component = adapter.manifest.hosts[name] else {
            throw SwiftWebLifecycleError.hostNotFound(adapter: selection.adapter, host: name)
        }
        return (adapter, name, component)
    }

    private func resolveDeployment(
        _ selector: String
    ) throws -> (adapter: Adapter, name: String, component: SwiftWebAdapterManifest.Deployment) {
        let selection = try componentSelection(selector)
        guard let adapter = adapters[selection.adapter] else {
            throw SwiftWebLifecycleError.adapterNotFound(selection.adapter)
        }
        let name = try selection.component ?? adapter.manifest.defaults.deployment.unwrap(
            or: SwiftWebLifecycleError.deploymentNotFound(
                adapter: selection.adapter,
                deployment: "default"
            )
        )
        guard let component = adapter.manifest.deployments[name] else {
            throw SwiftWebLifecycleError.deploymentNotFound(
                adapter: selection.adapter,
                deployment: name
            )
        }
        return (adapter, name, component)
    }

    private func componentSelection(_ selector: String) throws -> (adapter: String, component: String?) {
        let parts = selector.split(separator: "/", omittingEmptySubsequences: false).map(String.init)
        guard parts.count == 1 || parts.count == 2,
              let adapter = parts.first,
              !adapter.isEmpty,
              parts.allSatisfy({ !$0.isEmpty }) else {
            throw SwiftWebLifecycleError.malformedComponentSelector(selector)
        }
        return (adapter, parts.count == 2 ? parts[1] : nil)
    }
}

struct SwiftWebProjectResolver: Sendable {
    private let graphLoader: any SwiftPackageDependencyGraphLoading

    init(graphLoader: any SwiftPackageDependencyGraphLoading = SwiftPackageDependencyGraphLoader()) {
        self.graphLoader = graphLoader
    }

    func resolve(packageDirectory: URL) async throws -> SwiftWebProjectResolution {
        let packageDirectory = packageDirectory.standardizedFileURL
        let projectManifestURL = packageDirectory.appendingPathComponent("sweb.json")
        guard FileManager.default.fileExists(atPath: projectManifestURL.path) else {
            throw SwiftWebLifecycleError.projectManifestNotFound(projectManifestURL)
        }
        let projectManifest = try JSONDecoder().decode(
            SwiftWebProjectManifest.self,
            from: Data(contentsOf: projectManifestURL)
        )
        guard projectManifest.schemaVersion == 2 else {
            throw SwiftWebLifecycleError.unsupportedProjectSchema(projectManifest.schemaVersion)
        }

        let graph = try await graphLoader.load(packageDirectory: packageDirectory)
        var adapters: [String: SwiftWebProjectResolution.Adapter] = [:]
        for package in [graph.root] + graph.root.dependencies {
            let manifestURL = package.directory
                .appendingPathComponent("Adapter", isDirectory: true)
                .appendingPathComponent("sweb.json")
            guard FileManager.default.fileExists(atPath: manifestURL.path) else {
                continue
            }
            let manifest = try JSONDecoder().decode(
                SwiftWebAdapterManifest.self,
                from: Data(contentsOf: manifestURL)
            )
            guard manifest.schemaVersion == 2, manifest.kind == "adapter" else {
                throw SwiftWebLifecycleError.unsupportedAdapterSchema(
                    adapter: manifest.id,
                    schema: manifest.schemaVersion
                )
            }
            guard adapters[manifest.id] == nil else {
                throw SwiftWebLifecycleError.duplicateAdapter(manifest.id)
            }
            adapters[manifest.id] = SwiftWebProjectResolution.Adapter(
                package: package,
                directory: package.directory,
                manifest: manifest
            )
        }
        return SwiftWebProjectResolution(
            packageDirectory: packageDirectory,
            package: graph.root,
            manifest: projectManifest,
            adapters: adapters
        )
    }
}

private extension Optional {
    func unwrap(or error: @autoclosure () -> any Error) throws -> Wrapped {
        guard let value = self else {
            throw error()
        }
        return value
    }
}
