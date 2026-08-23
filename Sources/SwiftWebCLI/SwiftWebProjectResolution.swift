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
        let services: [Service]
    }

    struct Service: Sendable {
        let name: String
        let project: SwiftWebProjectManifest.Service
        let adapter: Adapter
        let componentName: String
        let component: SwiftWebAdapterManifest.Service
        let actorBinding: SwiftWebAdapterManifest.Deployment.ActorBinding?

        init(
            name: String,
            project: SwiftWebProjectManifest.Service,
            adapter: Adapter,
            componentName: String,
            component: SwiftWebAdapterManifest.Service,
            actorBinding: SwiftWebAdapterManifest.Deployment.ActorBinding? = nil
        ) {
            self.name = name
            self.project = project
            self.adapter = adapter
            self.componentName = componentName
            self.component = component
            self.actorBinding = actorBinding
        }
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
        let services = try resolveServices(
            named: projectEnvironment.services,
            deployment: deploymentSelection.component
        )
        var selectedActorContracts = Set<String>()
        for service in services {
            for actor in service.project.actors {
                let contract = "\(actor.module ?? actor.product).\(actor.type)"
                guard selectedActorContracts.insert(contract).inserted else {
                    throw SwiftWebLifecycleError.invalidActorBinding(
                        service: service.name,
                        reason: "Actor contract \(contract) is selected more than once"
                    )
                }
            }
        }
        return Environment(
            name: name,
            project: projectEnvironment,
            hostAdapter: hostSelection.adapter,
            hostName: hostSelection.name,
            host: hostSelection.component,
            deploymentAdapter: deploymentSelection.adapter,
            deploymentName: deploymentSelection.name,
            deployment: deploymentSelection.component,
            services: services
        )
    }

    private func resolveServices(
        named selectedNames: [String],
        deployment: SwiftWebAdapterManifest.Deployment
    ) throws -> [Service] {
        guard Set(selectedNames).count == selectedNames.count else {
            let duplicate =
                selectedNames.first { name in
                    selectedNames.filter { $0 == name }.count > 1
                } ?? "unknown"
            throw SwiftWebLifecycleError.duplicateEnvironmentService(duplicate)
        }
        let selected = Set(selectedNames)
        var resolvedByName: [String: Service] = [:]
        for name in selectedNames {
            guard SwiftWebManifestName.isValid(name) else {
                throw SwiftWebLifecycleError.invalidProjectServiceName(name)
            }
            guard let projectService = manifest.services[name] else {
                throw SwiftWebLifecycleError.projectServiceNotFound(name)
            }
            guard projectService.adapterTraits.allSatisfy(Self.isValidAdapterTrait),
                Set(projectService.adapterTraits).count
                    == projectService.adapterTraits.count
            else {
                throw SwiftWebLifecycleError.invalidServiceAdapterTraits(
                    service: name,
                    traits: projectService.adapterTraits
                )
            }
            for dependency in projectService.dependsOn where !selected.contains(dependency) {
                throw SwiftWebLifecycleError.missingServiceDependency(
                    service: name,
                    dependency: dependency
                )
            }
            let selection = try resolveService(projectService.adapter)
            for actor in projectService.actors {
                guard !actor.product.isEmpty,
                    Self.isValidSwiftIdentifier(actor.module ?? actor.product),
                    Self.isValidSwiftTypeName(actor.type)
                else {
                    throw SwiftWebLifecycleError.invalidActorBinding(
                        service: name,
                        reason: "Actor product, module, and type must form a valid concrete Swift Actor declaration"
                    )
                }
            }
            let producedArtifacts = Set(selection.component.produces)
            let acceptedArtifacts = Set(deployment.acceptsServiceArtifacts)
            guard !producedArtifacts.isDisjoint(with: acceptedArtifacts) else {
                throw SwiftWebLifecycleError.incompatibleServiceArtifacts(
                    service: name,
                    produces: selection.component.produces,
                    accepts: deployment.acceptsServiceArtifacts
                )
            }
            let actorBindingMatches = selection.component.produces.compactMap {
                deployment.actorBindings[$0]
            }
            if !projectService.actors.isEmpty, actorBindingMatches.count != 1 {
                throw SwiftWebLifecycleError.invalidActorBinding(
                    service: name,
                    reason: actorBindingMatches.isEmpty
                        ? "selected deployment does not provide an Actor binding for the service artifact"
                        : "selected deployment provides multiple Actor bindings for the service artifacts"
                )
            }
            resolvedByName[name] = Service(
                name: name,
                project: projectService,
                adapter: selection.adapter,
                componentName: selection.name,
                component: selection.component,
                actorBinding: actorBindingMatches.first
            )
        }

        var remainingDependencies = Dictionary(
            uniqueKeysWithValues: selectedNames.map { name in
                (name, Set(manifest.services[name]?.dependsOn ?? []))
            }
        )
        var ordered: [Service] = []
        while ordered.count < selectedNames.count {
            let readyNames = selectedNames.filter {
                remainingDependencies[$0]?.isEmpty == true
            }
            guard let nextName = readyNames.first,
                let next = resolvedByName[nextName]
            else {
                throw SwiftWebLifecycleError.cyclicServiceDependencies(
                    remainingDependencies.keys.sorted()
                )
            }
            ordered.append(next)
            remainingDependencies.removeValue(forKey: nextName)
            for name in Array(remainingDependencies.keys) {
                remainingDependencies[name]?.remove(nextName)
            }
        }
        return ordered
    }

    private static func isValidAdapterTrait(_ trait: String) -> Bool {
        guard !trait.isEmpty else {
            return false
        }
        return trait.utf8.allSatisfy { byte in
            (UInt8(ascii: "a")...UInt8(ascii: "z")).contains(byte)
                || (UInt8(ascii: "A")...UInt8(ascii: "Z")).contains(byte)
                || (UInt8(ascii: "0")...UInt8(ascii: "9")).contains(byte)
                || byte == UInt8(ascii: "-")
                || byte == UInt8(ascii: "_")
        }
    }

    private static func isValidSwiftTypeName(_ name: String) -> Bool {
        let components = name.split(separator: ".", omittingEmptySubsequences: false)
        return !components.isEmpty
            && components.allSatisfy { isValidSwiftIdentifier(String($0)) }
    }

    private static func isValidSwiftIdentifier(_ name: String) -> Bool {
        guard let first = name.unicodeScalars.first,
            CharacterSet.letters.union(CharacterSet(charactersIn: "_")).contains(first)
        else {
            return false
        }
        return name.unicodeScalars.dropFirst().allSatisfy {
            CharacterSet.alphanumerics.union(CharacterSet(charactersIn: "_")).contains($0)
        }
    }

    private func resolveHost(
        _ selector: String
    ) throws -> (adapter: Adapter, name: String, component: SwiftWebAdapterManifest.Host) {
        let selection = try componentSelection(selector)
        guard let adapter = adapters[selection.adapter] else {
            throw SwiftWebLifecycleError.adapterNotFound(selection.adapter)
        }
        let name =
            try selection.component
            ?? adapter.manifest.defaults.host.unwrap(
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
        let name =
            try selection.component
            ?? adapter.manifest.defaults.deployment.unwrap(
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

    private func resolveService(
        _ selector: String
    ) throws -> (adapter: Adapter, name: String, component: SwiftWebAdapterManifest.Service) {
        let selection = try componentSelection(selector)
        guard let adapter = adapters[selection.adapter] else {
            throw SwiftWebLifecycleError.adapterNotFound(selection.adapter)
        }
        guard let name = selection.component,
            let component = adapter.manifest.services[name]
        else {
            throw SwiftWebLifecycleError.serviceNotFound(
                adapter: selection.adapter,
                service: selection.component ?? "default"
            )
        }
        return (adapter, name, component)
    }

    private func componentSelection(
        _ selector: String
    ) throws -> (
        adapter: String, component: String?
    ) {
        let parts = selector.split(separator: "/", omittingEmptySubsequences: false).map(String.init)
        guard parts.count == 1 || parts.count == 2,
            let adapter = parts.first,
            !adapter.isEmpty,
            parts.allSatisfy({ !$0.isEmpty })
        else {
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
        guard projectManifest.schemaVersion == 3 else {
            throw SwiftWebLifecycleError.unsupportedProjectSchema(projectManifest.schemaVersion)
        }
        for name in projectManifest.environments.keys {
            guard SwiftWebManifestName.isValid(name) else {
                throw SwiftWebLifecycleError.invalidProjectEnvironmentName(name)
            }
        }
        for name in projectManifest.services.keys {
            guard SwiftWebManifestName.isValid(name) else {
                throw SwiftWebLifecycleError.invalidProjectServiceName(name)
            }
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
            guard manifest.schemaVersion == 3, manifest.kind == "adapter" else {
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

extension Optional {
    fileprivate func unwrap(or error: @autoclosure () -> any Error) throws -> Wrapped {
        guard let value = self else {
            throw error()
        }
        return value
    }
}
