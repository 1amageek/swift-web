import Foundation

struct SwiftWebEnvironmentMaterializer: Sendable {
    struct MaterializedEnvironment: Sendable {
        let environment: SwiftWebProjectResolution.Environment
        let rootDirectory: URL
        let workspaceDirectory: URL
        let substitutions: [String: String]
    }

    private struct MaterializationRecord: Codable {
        let schemaVersion: Int
        let managedPaths: [String]
    }

    private struct PlanLock: Codable {
        struct Component: Codable {
            let adapter: String
            let name: String
            let packageIdentity: String
            let version: String
            let path: String
        }

        struct Service: Codable {
            struct Actor: Codable {
                let product: String
                let module: String
                let type: String
            }

            let name: String
            let applicationProduct: String
            let applicationType: String
            let adapterTraits: [String]
            let actors: [Actor]
            let component: Component
        }

        let schemaVersion: Int
        let environment: String
        let applicationProduct: String
        let applicationType: String
        let host: Component
        let deployment: Component
        let services: [Service]
    }

    func materialize(
        resolution: SwiftWebProjectResolution,
        environment: SwiftWebProjectResolution.Environment
    ) throws -> MaterializedEnvironment {
        let environmentsDirectory = resolution.packageDirectory
            .appendingPathComponent(".swiftweb", isDirectory: true)
            .appendingPathComponent("generated", isDirectory: true)
            .appendingPathComponent("environments", isDirectory: true)
        let rootDirectory = try safeRelativeURL(
            environment.name,
            under: environmentsDirectory
        )
        let workspaceDirectory = rootDirectory.appendingPathComponent("workspace", isDirectory: true)
        try FileManager.default.createDirectory(
            at: workspaceDirectory,
            withIntermediateDirectories: true
        )

        let substitutions = try substitutions(
            resolution: resolution,
            environment: environment,
            rootDirectory: rootDirectory,
            workspaceDirectory: workspaceDirectory
        )
        var managedPaths = Set<String>()
        for service in environment.services {
            let serviceWorkspace =
                workspaceDirectory
                .appendingPathComponent("services", isDirectory: true)
                .appendingPathComponent(service.name, isDirectory: true)
            let serviceSubstitutions = serviceSubstitutions(
                service,
                resolution: resolution,
                serviceWorkspace: serviceWorkspace,
                substitutions: substitutions
            )
            for template in service.component.templates {
                try copyTemplate(
                    template,
                    adapterDirectory: service.adapter.directory,
                    destinationRoot: serviceWorkspace,
                    workspaceDirectory: workspaceDirectory,
                    substitutions: serviceSubstitutions,
                    managedPaths: &managedPaths
                )
            }
            for overlay in service.project.overlays {
                let source = try safeRelativeURL(
                    overlay.source,
                    under: resolution.packageDirectory
                )
                let destination = try safeRelativeURL(
                    overlay.destination,
                    under: serviceWorkspace
                )
                try copyDirectory(
                    from: source,
                    to: destination,
                    sourceRoot: source,
                    workspaceDirectory: workspaceDirectory,
                    substitutions: serviceSubstitutions,
                    excludedPaths: overlay.excluding,
                    managedPaths: &managedPaths
                )
            }
        }
        for template in environment.host.templates {
            try copyTemplate(
                template,
                adapterDirectory: environment.hostAdapter.directory,
                destinationRoot: workspaceDirectory,
                workspaceDirectory: workspaceDirectory,
                substitutions: substitutions,
                managedPaths: &managedPaths
            )
        }
        for template in environment.deployment.templates {
            try copyTemplate(
                template,
                adapterDirectory: environment.deploymentAdapter.directory,
                destinationRoot: workspaceDirectory,
                workspaceDirectory: workspaceDirectory,
                substitutions: substitutions,
                managedPaths: &managedPaths
            )
        }
        for overlay in environment.project.overlays {
            let source = try safeRelativeURL(
                overlay.source,
                under: resolution.packageDirectory
            )
            let destination = try safeRelativeURL(
                overlay.destination,
                under: workspaceDirectory
            )
            try copyDirectory(
                from: source,
                to: destination,
                sourceRoot: source,
                workspaceDirectory: workspaceDirectory,
                substitutions: substitutions,
                excludedPaths: overlay.excluding,
                managedPaths: &managedPaths
            )
        }

        try removeStaleManagedPaths(
            rootDirectory: rootDirectory,
            workspaceDirectory: workspaceDirectory,
            nextManagedPaths: managedPaths
        )
        try writeMaterializationRecord(managedPaths, rootDirectory: rootDirectory)
        try writePlanLock(
            resolution: resolution,
            environment: environment,
            rootDirectory: rootDirectory
        )
        return MaterializedEnvironment(
            environment: environment,
            rootDirectory: rootDirectory,
            workspaceDirectory: workspaceDirectory,
            substitutions: substitutions
        )
    }

    private func substitutions(
        resolution: SwiftWebProjectResolution,
        environment: SwiftWebProjectResolution.Environment,
        rootDirectory: URL,
        workspaceDirectory: URL
    ) throws -> [String: String] {
        let application = resolution.manifest.application
        var values: [String: String] = [
            "project.root": resolution.packageDirectory.path,
            "generated.root": rootDirectory.path,
            "workspace.root": workspaceDirectory.path,
            "environment.name": environment.name,
            "application.packageIdentity": resolution.package.identity,
            "application.product": application.product,
            "application.module": application.module ?? application.product,
            "application.type": application.type,
            "application.kebabName": Self.kebabCase(application.product),
        ]
        for (adapterID, adapter) in resolution.adapters {
            values["adapter.\(adapterID).root"] = adapter.directory.path
            values["adapter.\(adapterID).swiftPackageRequirement"] =
                swiftPackageRequirement(adapter.package)
        }
        values["adapter.\(environment.hostAdapter.manifest.id).root"] =
            environment.hostAdapter.directory.path
        values["adapter.\(environment.hostAdapter.manifest.id).swiftPackageRequirement"] =
            swiftPackageRequirement(environment.hostAdapter.package)
        values["adapter.\(environment.deploymentAdapter.manifest.id).root"] =
            environment.deploymentAdapter.directory.path
        values["adapter.\(environment.deploymentAdapter.manifest.id).swiftPackageRequirement"] =
            swiftPackageRequirement(environment.deploymentAdapter.package)
        values.merge(environment.host.variables) { _, host in host }
        values.merge(environment.deployment.variables) { _, deployment in deployment }
        for service in environment.services {
            let application = service.project.application
            let prefix = "services.\(service.name)"
            let serviceWorkspace =
                workspaceDirectory
                .appendingPathComponent("services", isDirectory: true)
                .appendingPathComponent(service.name, isDirectory: true)
            values["\(prefix).name"] = service.name
            values["\(prefix).workspace"] = serviceWorkspace.path
            values["\(prefix).application.packageIdentity"] = resolution.package.identity
            values["\(prefix).application.product"] = application.product
            values["\(prefix).application.module"] = application.module ?? application.product
            values["\(prefix).application.type"] = application.type
            values["\(prefix).application.kebabName"] = Self.kebabCase(application.product)
            values["\(prefix).adapter.root"] = service.adapter.directory.path
            values["\(prefix).adapter.swiftPackageRequirement"] =
                swiftPackageRequirement(service.adapter.package)
            values["\(prefix).adapter.swiftPackageTraits"] =
                swiftPackageTraits(service.project.adapterTraits)
            for (key, value) in service.component.variables {
                values["\(prefix).\(key)"] = value
            }
            for (key, value) in service.project.variables {
                values["\(prefix).\(key)"] = value
            }
        }
        let actors = try actorSubstitutions(
            resolution: resolution,
            environment: environment,
            substitutions: values
        )
        values.merge(actors) { _, actor in actor }
        return values
    }

    private func actorSubstitutions(
        resolution: SwiftWebProjectResolution,
        environment: SwiftWebProjectResolution.Environment,
        substitutions: [String: String]
    ) throws -> [String: String] {
        var imports = Set<String>()
        var productDependencies = Set<String>()
        var bindingExpressions: [String] = []
        var deploymentBindings: [[String: Any]] = []

        for service in environment.services {
            guard let bindingTemplate = service.actorBinding else {
                continue
            }
            let servicePrefix = "services.\(service.name)"
            for actor in service.project.actors {
                let module = actor.module ?? actor.product
                var actorValues = substitutions
                for (key, value) in substitutions where key.hasPrefix(servicePrefix + ".") {
                    actorValues["service." + key.dropFirst(servicePrefix.count + 1)] = value
                }
                actorValues["actor.product"] = actor.product
                actorValues["actor.module"] = module
                actorValues["actor.type"] = actor.type
                actorValues["actor.service"] = service.name
                actorValues["actor.servicePrefix"] = servicePrefix
                let hostRoute = try renderedRoute(
                    bindingTemplate.hostRoute,
                    service: service.name,
                    substitutions: actorValues
                )
                let clientRoute = try bindingTemplate.clientRoute.map {
                    try renderedRoute(
                        $0,
                        service: service.name,
                        substitutions: actorValues
                    )
                }
                let expression = swiftServiceBinding(
                    module: module,
                    type: actor.type,
                    hostRoute: hostRoute,
                    clientRoute: clientRoute
                )
                imports.insert("import \(module)")
                if actor.product != resolution.manifest.application.product {
                    productDependencies.insert(
                        ".product(name: \"\(swiftString(actor.product))\", package: \"\(swiftString(resolution.package.identity))\")"
                    )
                }
                bindingExpressions.append(expression)
                let configuration = bindingTemplate.configuration.mapValues {
                    render($0, substitutions: actorValues)
                }
                guard configuration.values.allSatisfy({ !$0.contains("{{") }) else {
                    throw SwiftWebLifecycleError.invalidActorBinding(
                        service: service.name,
                        reason: "Actor binding configuration contains an unresolved substitution"
                    )
                }
                deploymentBindings.append([
                    "service": service.name,
                    "product": actor.product,
                    "module": module,
                    "type": actor.type,
                    "hostRoute": routeJSONObject(hostRoute),
                    "clientRoute": clientRoute.map { routeJSONObject($0) } ?? NSNull(),
                    "configuration": configuration,
                ])
            }
        }

        let bindings = bindingExpressions
            .map { indent($0, spaces: 12) }
            .joined(separator: ",\n")
        let dependencies = productDependencies.sorted().map { "                \($0)," }.joined(separator: "\n")
        return [
            "actors.swiftImports": imports.sorted().joined(separator: "\n"),
            "actors.swiftProductDependencies": dependencies,
            "actors.swiftServiceBindings": bindings,
            "actors.deploymentBindingsJSON": try jsonString(deploymentBindings),
        ]
    }

    private func renderedRoute(
        _ route: SwiftWebAdapterManifest.Deployment.ActorBinding.Route,
        service: String,
        substitutions: [String: String]
    ) throws -> SwiftWebAdapterManifest.Deployment.ActorBinding.Route {
        let rendered = SwiftWebAdapterManifest.Deployment.ActorBinding.Route(
            transport: render(route.transport, substitutions: substitutions),
            endpointPrefix: render(route.endpointPrefix, substitutions: substitutions),
            endpointSuffix: render(route.endpointSuffix, substitutions: substitutions)
        )
        guard !rendered.transport.isEmpty,
              !rendered.endpointPrefix.isEmpty,
              !rendered.transport.contains("{{"),
              !rendered.endpointPrefix.contains("{{"),
              !rendered.endpointSuffix.contains("{{")
        else {
            throw SwiftWebLifecycleError.invalidActorBinding(
                service: service,
                reason: "Actor route must have a resolved transport and endpoint prefix"
            )
        }
        return rendered
    }

    private func swiftServiceBinding(
        module: String,
        type: String,
        hostRoute: SwiftWebAdapterManifest.Deployment.ActorBinding.Route,
        clientRoute: SwiftWebAdapterManifest.Deployment.ActorBinding.Route?
    ) -> String {
        let client: String
        if let clientRoute {
            client = """
                .init(
                    transport: .init("\(swiftString(clientRoute.transport))"),
                    endpointPrefix: "\(swiftString(clientRoute.endpointPrefix))",
                    endpointSuffix: "\(swiftString(clientRoute.endpointSuffix))"
                )
                """
        } else {
            client = "nil"
        }
        return """
            .init(
                actorType: \(module).\(type).actorTypeDescriptor.id,
                hostRoute: .init(
                    transport: .init("\(swiftString(hostRoute.transport))"),
                    endpointPrefix: "\(swiftString(hostRoute.endpointPrefix))",
                    endpointSuffix: "\(swiftString(hostRoute.endpointSuffix))"
                ),
                clientRoute: \(client)
            )
            """
    }

    private func indent(_ value: String, spaces: Int) -> String {
        let prefix = String(repeating: " ", count: spaces)
        return value.split(separator: "\n", omittingEmptySubsequences: false)
            .map { prefix + $0 }
            .joined(separator: "\n")
    }

    private func routeJSONObject(
        _ route: SwiftWebAdapterManifest.Deployment.ActorBinding.Route
    ) -> [String: String] {
        [
            "transport": route.transport,
            "endpointPrefix": route.endpointPrefix,
            "endpointSuffix": route.endpointSuffix,
        ]
    }

    private func jsonString(_ object: Any) throws -> String {
        let data = try JSONSerialization.data(
            withJSONObject: object,
            options: [.sortedKeys, .withoutEscapingSlashes]
        )
        return String(decoding: data, as: UTF8.self)
    }

    private func serviceSubstitutions(
        _ service: SwiftWebProjectResolution.Service,
        resolution: SwiftWebProjectResolution,
        serviceWorkspace: URL,
        substitutions: [String: String]
    ) -> [String: String] {
        let application = service.project.application
        var values = substitutions
        values["service.name"] = service.name
        values["service.workspace"] = serviceWorkspace.path
        values["service.application.packageIdentity"] = resolution.package.identity
        values["service.application.product"] = application.product
        values["service.application.module"] = application.module ?? application.product
        values["service.application.type"] = application.type
        values["service.application.kebabName"] = Self.kebabCase(application.product)
        values["service.adapter.root"] = service.adapter.directory.path
        values["service.adapter.swiftPackageRequirement"] =
            swiftPackageRequirement(service.adapter.package)
        values["service.adapter.swiftPackageTraits"] =
            swiftPackageTraits(service.project.adapterTraits)
        for (key, value) in service.component.variables {
            values["service.\(key)"] = value
        }
        for (key, value) in service.project.variables {
            values["service.\(key)"] = value
        }
        return values
    }

    private func swiftPackageRequirement(
        _ package: SwiftPackageDependencyGraph.Package
    ) -> String {
        if package.version != "unspecified",
            package.url.contains("://"),
            !package.url.hasPrefix("file://")
        {
            return "url: \"\(swiftString(package.url))\", exact: \"\(swiftString(package.version))\""
        }
        return "path: \"\(swiftString(package.directory.path))\""
    }

    private func swiftPackageTraits(_ traits: [String]) -> String {
        guard !traits.isEmpty else {
            return ""
        }
        let values = traits.map { "\"\(swiftString($0))\"" }.joined(separator: ", ")
        return ", traits: [\(values)]"
    }

    private func swiftString(_ value: String) -> String {
        value
            .replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "\"", with: "\\\"")
            .replacingOccurrences(of: "\n", with: "\\n")
            .replacingOccurrences(of: "\r", with: "\\r")
            .replacingOccurrences(of: "\t", with: "\\t")
    }

    private func copyTemplate(
        _ template: SwiftWebAdapterManifest.Template,
        adapterDirectory: URL,
        destinationRoot: URL,
        workspaceDirectory: URL,
        substitutions: [String: String],
        managedPaths: inout Set<String>
    ) throws {
        let source = try safeRelativeURL(template.source, under: adapterDirectory)
        let destination = try safeRelativeURL(template.destination, under: destinationRoot)
        guard FileManager.default.fileExists(atPath: source.path) else {
            throw SwiftWebLifecycleError.missingTemplate(source)
        }
        try copyDirectory(
            from: source,
            to: destination,
            sourceRoot: source,
            workspaceDirectory: workspaceDirectory,
            substitutions: substitutions,
            excludedPaths: [],
            managedPaths: &managedPaths
        )
    }

    private func copyDirectory(
        from sourceDirectory: URL,
        to destinationDirectory: URL,
        sourceRoot: URL,
        workspaceDirectory: URL,
        substitutions: [String: String],
        excludedPaths: [String],
        managedPaths: inout Set<String>
    ) throws {
        try FileManager.default.createDirectory(
            at: destinationDirectory,
            withIntermediateDirectories: true
        )
        let children = try FileManager.default.contentsOfDirectory(
            at: sourceDirectory,
            includingPropertiesForKeys: [.isDirectoryKey, .isRegularFileKey, .isSymbolicLinkKey],
            options: []
        )
        for child in children {
            let sourceRelativePath = try relativePath(child, under: sourceRoot)
            guard !isExcluded(sourceRelativePath, by: excludedPaths) else {
                continue
            }
            let values = try child.resourceValues(
                forKeys: [.isDirectoryKey, .isRegularFileKey, .isSymbolicLinkKey]
            )
            guard values.isSymbolicLink != true else {
                throw SwiftWebLifecycleError.unsafeTemplateEntry(child)
            }
            let destination = destinationDirectory.appendingPathComponent(child.lastPathComponent)
            if values.isDirectory == true {
                try copyDirectory(
                    from: child,
                    to: destination,
                    sourceRoot: sourceRoot,
                    workspaceDirectory: workspaceDirectory,
                    substitutions: substitutions,
                    excludedPaths: excludedPaths,
                    managedPaths: &managedPaths
                )
                continue
            }
            guard values.isRegularFile == true else {
                throw SwiftWebLifecycleError.unsafeTemplateEntry(child)
            }
            let data = try Data(contentsOf: child)
            let nextData: Data
            if let text = String(data: data, encoding: .utf8) {
                nextData = Data(render(text, substitutions: substitutions).utf8)
            } else {
                nextData = data
            }
            try writeIfChanged(nextData, to: destination)
            if let permissions = try FileManager.default.attributesOfItem(atPath: child.path)[
                .posixPermissions
            ] {
                try FileManager.default.setAttributes(
                    [.posixPermissions: permissions],
                    ofItemAtPath: destination.path
                )
            }
            managedPaths.insert(try relativePath(destination, under: workspaceDirectory))
        }
    }

    private func removeStaleManagedPaths(
        rootDirectory: URL,
        workspaceDirectory: URL,
        nextManagedPaths: Set<String>
    ) throws {
        let recordURL = rootDirectory.appendingPathComponent("materialization.json")
        guard FileManager.default.fileExists(atPath: recordURL.path) else {
            return
        }
        let record = try JSONDecoder().decode(
            MaterializationRecord.self,
            from: Data(contentsOf: recordURL)
        )
        for stalePath in Set(record.managedPaths).subtracting(nextManagedPaths) {
            let staleURL = try safeRelativeURL(stalePath, under: workspaceDirectory)
            if FileManager.default.fileExists(atPath: staleURL.path) {
                try FileManager.default.removeItem(at: staleURL)
            }
        }
    }

    private func writeMaterializationRecord(
        _ managedPaths: Set<String>,
        rootDirectory: URL
    ) throws {
        let record = MaterializationRecord(
            schemaVersion: 1,
            managedPaths: managedPaths.sorted()
        )
        try writeJSON(record, to: rootDirectory.appendingPathComponent("materialization.json"))
    }

    private func writePlanLock(
        resolution: SwiftWebProjectResolution,
        environment: SwiftWebProjectResolution.Environment,
        rootDirectory: URL
    ) throws {
        func component(
            adapter: SwiftWebProjectResolution.Adapter,
            name: String
        ) -> PlanLock.Component {
            PlanLock.Component(
                adapter: adapter.manifest.id,
                name: name,
                packageIdentity: adapter.package.identity,
                version: adapter.package.version,
                path: adapter.directory.path
            )
        }
        let lock = PlanLock(
            schemaVersion: 3,
            environment: environment.name,
            applicationProduct: resolution.manifest.application.product,
            applicationType: resolution.manifest.application.type,
            host: component(adapter: environment.hostAdapter, name: environment.hostName),
            deployment: component(
                adapter: environment.deploymentAdapter,
                name: environment.deploymentName
            ),
            services: environment.services.map { service in
                PlanLock.Service(
                    name: service.name,
                    applicationProduct: service.project.application.product,
                    applicationType: service.project.application.type,
                    adapterTraits: service.project.adapterTraits,
                    actors: service.project.actors.map { actor in
                        PlanLock.Service.Actor(
                            product: actor.product,
                            module: actor.module ?? actor.product,
                            type: actor.type
                        )
                    },
                    component: component(
                        adapter: service.adapter,
                        name: service.componentName
                    )
                )
            }
        )
        try writeJSON(lock, to: rootDirectory.appendingPathComponent("plan.lock.json"))
    }

    private func writeJSON<Value: Encodable>(_ value: Value, to url: URL) throws {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
        var data = try encoder.encode(value)
        data.append(0x0A)
        try writeIfChanged(data, to: url)
    }

    private func writeIfChanged(_ data: Data, to url: URL) throws {
        try FileManager.default.createDirectory(
            at: url.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        if FileManager.default.fileExists(atPath: url.path),
            try Data(contentsOf: url) == data
        {
            return
        }
        try data.write(to: url, options: .atomic)
    }

    private func render(_ text: String, substitutions: [String: String]) -> String {
        substitutions.reduce(text) { partial, entry in
            partial.replacingOccurrences(of: "{{\(entry.key)}}", with: entry.value)
        }
    }

    private func safeRelativeURL(_ relativePath: String, under root: URL) throws -> URL {
        let parts = relativePath.split(separator: "/", omittingEmptySubsequences: false)
        guard !relativePath.hasPrefix("/"),
            parts.allSatisfy({ !$0.isEmpty && $0 != "." && $0 != ".." }) || relativePath.isEmpty
        else {
            throw SwiftWebLifecycleError.invalidTemplatePath(relativePath)
        }
        return relativePath.isEmpty
            ? root.standardizedFileURL
            : root.appendingPathComponent(relativePath).standardizedFileURL
    }

    private func relativePath(_ url: URL, under root: URL) throws -> String {
        let rootPath = root.standardizedFileURL.path
        let candidatePath = url.standardizedFileURL.path
        let prefix = rootPath.hasSuffix("/") ? rootPath : rootPath + "/"
        guard candidatePath.hasPrefix(prefix) else {
            throw SwiftWebLifecycleError.invalidTemplatePath(candidatePath)
        }
        return String(candidatePath.dropFirst(prefix.count))
    }

    private func isExcluded(_ path: String, by excludedPaths: [String]) -> Bool {
        excludedPaths.contains { excluded in
            path == excluded || path.hasPrefix(excluded + "/")
        }
    }

    private static func kebabCase(_ value: String) -> String {
        var result = ""
        for character in value {
            if character.isUppercase, !result.isEmpty {
                result.append("-")
            }
            result.append(character.lowercased())
        }
        return result
    }
}
