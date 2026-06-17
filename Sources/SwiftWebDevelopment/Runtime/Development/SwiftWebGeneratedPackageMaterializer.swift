import Darwin
import Foundation
import SwiftHTML

public struct SwiftWebGeneratedPackageMaterializer: Sendable {
    public var appPackageDirectory: URL
    public var generatedPackageDirectory: URL
    public var appProductName: String?
    public var serverProductName: String
    public var devProductName: String?

    public init(
        appPackageDirectory: URL,
        generatedPackageDirectory: URL? = nil,
        appProductName: String? = nil,
        serverProductName: String = "app-server",
        devProductName: String? = nil
    ) {
        let standardizedAppPackageDirectory = appPackageDirectory.standardizedFileURL
        self.appPackageDirectory = standardizedAppPackageDirectory
        self.generatedPackageDirectory = generatedPackageDirectory?.standardizedFileURL
            ?? standardizedAppPackageDirectory
                .appendingPathComponent(".swiftweb", isDirectory: true)
                .appendingPathComponent("generated", isDirectory: true)
                .standardizedFileURL
        self.appProductName = appProductName
        self.serverProductName = serverProductName
        self.devProductName = devProductName
    }

    private var serverPackageDirectory: URL {
        generatedPackageDirectory
            .appendingPathComponent("server", isDirectory: true)
            .standardizedFileURL
    }

    private var devPackageDirectory: URL {
        generatedPackageDirectory
            .appendingPathComponent("dev", isDirectory: true)
            .standardizedFileURL
    }

    private var wasmPackageDirectory: URL {
        generatedPackageDirectory
            .appendingPathComponent("wasm", isDirectory: true)
            .standardizedFileURL
    }

    private var developmentServerProductName: String {
        "\(serverProductName)-dev"
    }

    public func materialize() throws -> SwiftWebGeneratedPackage {
        let packageName = try SwiftWebPackageManifestInspector.packageName(in: appPackageDirectory)
        let appProductName = appProductName ?? packageName
        let devProductName = devProductName ?? "\(packageName)-dev"
        let swiftWebPackageDirectory = try SwiftWebPackageManifestInspector.localDependencyRoot(
            named: "swift-web",
            in: appPackageDirectory
        )
        let swiftHTMLPackageDirectory = try resolveLocalSwiftHTMLPackageDirectory(
            swiftWebPackageDirectory: swiftWebPackageDirectory
        )
        try FileManager.default.createDirectory(
            at: generatedPackageDirectory,
            withIntermediateDirectories: true
        )
        try FileManager.default.createDirectory(
            at: serverPackageDirectory,
            withIntermediateDirectories: true
        )
        try FileManager.default.createDirectory(
            at: devPackageDirectory,
            withIntermediateDirectories: true
        )
        try FileManager.default.createDirectory(
            at: wasmPackageDirectory,
            withIntermediateDirectories: true
        )
        return try withMaterializationLock {
            try materializeUnlocked(
                packageName: packageName,
                appProductName: appProductName,
                devProductName: devProductName,
                swiftWebPackageDirectory: swiftWebPackageDirectory,
                swiftHTMLPackageDirectory: swiftHTMLPackageDirectory
            )
        }
    }

    private func resolveLocalSwiftHTMLPackageDirectory(
        swiftWebPackageDirectory: URL
    ) throws -> URL? {
        if let appSwiftHTMLPackageDirectory = try SwiftWebPackageManifestInspector.optionalLocalDependencyRoot(
            named: "swift-html",
            in: appPackageDirectory
        ) {
            return appSwiftHTMLPackageDirectory
        }

        return try SwiftWebPackageManifestInspector.optionalLocalDependencyRoot(
            named: "swift-html",
            in: swiftWebPackageDirectory
        )
    }

    private func materializeUnlocked(
        packageName: String,
        appProductName: String,
        devProductName: String,
        swiftWebPackageDirectory: URL,
        swiftHTMLPackageDirectory: URL?
    ) throws -> SwiftWebGeneratedPackage {
        let clientComponents = try discoverClientComponents(appProductName: appProductName)
        let wasmRuntimeTargets = wasmRuntimeTargets(
            appProductName: appProductName,
            for: clientComponents
        )
        let wasmRuntimeTargetNames = wasmRuntimeTargets.map(\.targetName)
        let wasmProductNames = wasmRuntimeTargetNames.map(Self.productName(forWasmRuntimeTarget:))
        let wasmRuntimes = wasmRuntimeTargets.map { target in
            SwiftWebGeneratedWasmRuntime(
                packageDirectory: wasmPackageDirectory,
                targetName: target.targetName,
                productName: Self.productName(forWasmRuntimeTarget: target.targetName),
                componentTypeNames: target.componentTypeNames,
                bundleID: target.bundleID,
                assetPath: Self.assetPath(forWasmRuntimeTarget: target.targetName)
            )
        }

        try removeLegacyMaterializationLockFile()
        try removeLegacySinglePackageLayout()
        try writeServerGeneratedSources(
            appProductName: appProductName,
            wasmRuntimeTargets: wasmRuntimeTargets
        )
        try writeDevGeneratedSources(
            appProductName: appProductName,
            wasmRuntimeTargets: wasmRuntimeTargets
        )
        try writeWasmGeneratedSources(
            appProductName: appProductName,
            wasmRuntimeTargets: wasmRuntimeTargets
        )
        try copyClientSources(appProductName: appProductName, to: wasmPackageDirectory)
        try copyClientRuntimeSources(from: swiftWebPackageDirectory, to: wasmPackageDirectory)
        try removeStaleWasmSourceTargets(
            keeping: Set(
                [appProductName, "SwiftWebActors", "SwiftWebUI", "SwiftWebUIRuntime"]
                    + wasmRuntimeTargetNames
            )
        )
        let serverPackageSwiftContents = serverPackageSwift(
            appPackageName: packageName,
            appPackageDependencyName: Self.localPackageIdentity(for: appPackageDirectory),
            appProductName: appProductName
        )
        let devPackageSwiftContents = devPackageSwift(
            appPackageName: packageName,
            appPackageDependencyName: Self.localPackageIdentity(for: appPackageDirectory),
            appProductName: appProductName,
            developmentServerProductName: developmentServerProductName,
            devProductName: devProductName,
            swiftWebPackageDirectory: swiftWebPackageDirectory
        )
        let wasmPackageSwiftContents = wasmPackageSwift(
            appPackageName: packageName,
            appProductName: appProductName,
            swiftHTMLPackageDirectory: swiftHTMLPackageDirectory,
            wasmRuntimeTargetNames: wasmRuntimeTargetNames
        )
        try removeGeneratedBuildDirectoryIfPackageChanged(
            in: serverPackageDirectory,
            nextPackageSwift: serverPackageSwiftContents
        )
        try removeGeneratedBuildDirectoryIfPackageChanged(
            in: devPackageDirectory,
            nextPackageSwift: devPackageSwiftContents
        )
        try removeGeneratedBuildDirectoryIfPackageChanged(
            in: wasmPackageDirectory,
            nextPackageSwift: wasmPackageSwiftContents
        )
        try writeIfChanged(
            serverPackageSwiftContents,
            to: serverPackageDirectory.appendingPathComponent("Package.swift")
        )
        try writeIfChanged(
            devPackageSwiftContents,
            to: devPackageDirectory.appendingPathComponent("Package.swift")
        )
        try writeIfChanged(
            wasmPackageSwiftContents,
            to: wasmPackageDirectory.appendingPathComponent("Package.swift")
        )
        try syncPackageResolved(to: serverPackageDirectory)
        try syncPackageResolved(to: devPackageDirectory)
        try syncPackageResolved(
            to: wasmPackageDirectory,
            keepingIdentities: ["javascriptkit", "swift-actor-runtime", "swift-syntax"]
        )

        return SwiftWebGeneratedPackage(
            appPackageDirectory: appPackageDirectory,
            rootDirectory: generatedPackageDirectory,
            packageDirectory: serverPackageDirectory,
            devPackageDirectory: devPackageDirectory,
            wasmPackageDirectory: wasmPackageDirectory,
            swiftWebPackageDirectory: swiftWebPackageDirectory,
            appProductName: appProductName,
            serverProductName: serverProductName,
            developmentServerProductName: developmentServerProductName,
            devProductName: devProductName,
            wasmProductNames: wasmProductNames,
            wasmRuntimes: wasmRuntimes
        )
    }

    private func withMaterializationLock<T>(_ body: () throws -> T) throws -> T {
        let descriptor = open(
            generatedPackageDirectory.path,
            O_RDONLY
        )
        guard descriptor >= 0 else {
            throw SwiftWebGeneratedPackageMaterializerError.materializationLockOpenFailed(
                generatedPackageDirectory,
                errno
            )
        }
        defer {
            _ = close(descriptor)
        }

        guard flock(descriptor, LOCK_EX) == 0 else {
            throw SwiftWebGeneratedPackageMaterializerError.materializationLockFailed(
                generatedPackageDirectory,
                errno
            )
        }
        defer {
            _ = flock(descriptor, LOCK_UN)
        }

        return try body()
    }

    private func removeLegacyMaterializationLockFile() throws {
        let lockFile = generatedPackageDirectory.appendingPathComponent(".materialize.lock")
        if FileManager.default.fileExists(atPath: lockFile.path) {
            try FileManager.default.removeItem(at: lockFile)
        }
    }

    private func removeLegacySinglePackageLayout() throws {
        for name in ["Package.swift", "Package.resolved"] {
            let url = generatedPackageDirectory.appendingPathComponent(name)
            if FileManager.default.fileExists(atPath: url.path) {
                try FileManager.default.removeItem(at: url)
            }
        }

        for name in ["Sources", ".build"] {
            let url = generatedPackageDirectory.appendingPathComponent(name, isDirectory: true)
            if FileManager.default.fileExists(atPath: url.path) {
                try FileManager.default.removeItem(at: url)
            }
        }
    }

    private func discoverClientComponents(appProductName: String) throws -> [ClientComponentDeclaration] {
        let sourceDirectory = appPackageDirectory
            .appendingPathComponent("Sources", isDirectory: true)
            .appendingPathComponent(appProductName, isDirectory: true)
        guard FileManager.default.fileExists(atPath: sourceDirectory.path) else {
            throw SwiftWebGeneratedPackageMaterializerError.clientSourceDirectoryNotFound(sourceDirectory)
        }

        let swiftFiles = try collectSwiftFiles(
            in: sourceDirectory,
            relativePath: ""
        )

        var declarations: [String: ClientComponentDeclaration] = [:]
        for file in swiftFiles {
            for declaration in try Self.clientComponents(in: file.url, relativePath: file.relativePath) {
                declarations[declaration.typeName] = declarations[declaration.typeName]?.merged(with: declaration)
                    ?? declaration
            }
        }

        for file in swiftFiles {
            let source = try String(contentsOf: file.url, encoding: .utf8)
            for typeName in declarations.keys {
                guard let override = try Self.modifierContractOverride(
                    for: typeName,
                    in: source
                ) else {
                    continue
                }
                declarations[typeName] = declarations[typeName]?.merged(with: override)
            }
        }

        return declarations.values.sorted { left, right in
            left.typeName < right.typeName
        }
    }

    private func collectSwiftFiles(
        in directory: URL,
        relativePath: String
    ) throws -> [(url: URL, relativePath: String)] {
        let children = try FileManager.default.contentsOfDirectory(
            at: directory,
            includingPropertiesForKeys: [.isDirectoryKey],
            options: [.skipsHiddenFiles]
        )

        var files: [(url: URL, relativePath: String)] = []
        for child in children {
            let relativeChildPath = relativePath.isEmpty
                ? child.lastPathComponent
                : "\(relativePath)/\(child.lastPathComponent)"
            guard !isServerOnly(relativePath: relativeChildPath) else {
                continue
            }

            let values = try child.resourceValues(forKeys: [.isDirectoryKey])
            if values.isDirectory == true {
                files.append(contentsOf: try collectSwiftFiles(in: child, relativePath: relativeChildPath))
            } else if child.pathExtension == "swift" {
                files.append((child, relativeChildPath))
            }
        }
        return files
    }

    private static func clientComponents(in file: URL, relativePath: String) throws -> [ClientComponentDeclaration] {
        let source = try String(contentsOf: file, encoding: .utf8)
        let pattern = #"(?:public\s+)?(?:struct|final\s+class|class)\s+([A-Za-z_][A-Za-z0-9_]*)\s*(?:<[^>{}]+>)?\s*:\s*([^{]+)"#
        let regex = try NSRegularExpression(pattern: pattern)
        let range = NSRange(source.startIndex..<source.endIndex, in: source)

        var declarations: [ClientComponentDeclaration] = []
        for match in regex.matches(in: source, range: range) {
            guard match.numberOfRanges > 2,
                  let nameRange = Range(match.range(at: 1), in: source),
                  let conformancesRange = Range(match.range(at: 2), in: source)
            else {
                continue
            }
            let conformances = source[conformancesRange]
            guard conformances.contains("ClientComponent") else {
                continue
            }
            let typeName = String(source[nameRange])
            let body = declarationBody(in: source, after: match.range)
            declarations.append(ClientComponentDeclaration(
                typeName: typeName,
                loadPolicy: try parseLoadPolicy(in: body) ?? .eager,
                bundlePolicy: try parseBundlePolicy(in: body) ?? .main
            ))
        }
        return declarations
    }

    private static func declarationBody(in source: String, after range: NSRange) -> String {
        guard let searchStart = Range(range, in: source)?.upperBound,
              let openingBrace = source[searchStart...].firstIndex(of: "{")
        else {
            return ""
        }

        var depth = 0
        var index = openingBrace
        while index < source.endIndex {
            let character = source[index]
            if character == "{" {
                depth += 1
            } else if character == "}" {
                depth -= 1
                if depth == 0 {
                    return String(source[openingBrace...index])
                }
            }
            index = source.index(after: index)
        }
        return String(source[openingBrace...])
    }

    private static func modifierContractOverride(
        for typeName: String,
        in source: String
    ) throws -> ClientComponentDeclaration? {
        var result = ClientComponentDeclaration(typeName: typeName)
        var found = false
        var searchRange = source.startIndex..<source.endIndex

        while let typeRange = source.range(of: "\(typeName)(", range: searchRange) {
            let windowEnd = source.index(
                typeRange.lowerBound,
                offsetBy: 600,
                limitedBy: source.endIndex
            ) ?? source.endIndex
            let window = String(source[typeRange.lowerBound..<windowEnd])
            if let loadPolicy = try parseLoadPolicy(in: window, requiresStatic: false) {
                result.loadPolicy = loadPolicy
                found = true
            }
            if let bundlePolicy = try parseBundlePolicy(in: window, requiresStatic: false) {
                result.bundlePolicy = bundlePolicy
                found = true
            }
            searchRange = typeRange.upperBound..<source.endIndex
        }

        return found ? result : nil
    }

    private static func parseLoadPolicy(
        in source: String,
        requiresStatic: Bool = true
    ) throws -> LoadPolicy? {
        let prefix = requiresStatic
            ? #"static\s+(?:let|var)\s+loadPolicy\b"#
            : #"\.loadPolicy\s*\("#
        let pattern = "\(prefix)[\\s\\S]{0,120}\\.(eager|visible|interaction|idle|manual)"
        guard let match = try firstMatch(pattern: pattern, in: source) else {
            return nil
        }
        guard let value = match[1] else {
            return nil
        }
        return LoadPolicy(rawValue: value)
    }

    private static func parseBundlePolicy(
        in source: String,
        requiresStatic: Bool = true
    ) throws -> BundlePolicy? {
        let prefix = requiresStatic
            ? #"static\s+(?:let|var)\s+bundle\b"#
            : #"\.bundle\s*\("#
        let pattern = "\(prefix)[\\s\\S]{0,160}\\.(main|component|named|shared)(?:\\(\\s*\"([^\"]+)\"\\s*\\))?"
        guard let match = try firstMatch(pattern: pattern, in: source) else {
            return nil
        }
        guard let value = match[1] else {
            return nil
        }
        switch value {
        case "main":
            return .main
        case "component":
            return .component
        case "named":
            return .named(match[2] ?? "")
        case "shared":
            return .shared(match[2] ?? "")
        default:
            return nil
        }
    }

    private static func firstMatch(
        pattern: String,
        in source: String
    ) throws -> [String?]? {
        let regex = try NSRegularExpression(pattern: pattern)
        let range = NSRange(source.startIndex..<source.endIndex, in: source)
        guard let match = regex.firstMatch(in: source, range: range) else {
            return nil
        }
        return (0..<match.numberOfRanges).map { index in
            guard let range = Range(match.range(at: index), in: source) else {
                return nil
            }
            return String(source[range])
        }
    }

    private static func resolvedBundleID(
        for component: ClientComponentDeclaration
    ) -> ClientBundleID? {
        switch component.bundlePolicy {
        case .main:
            if component.loadPolicy == .eager {
                return nil
            }
            return ClientBundleID("component-\(stableHashHex(component.typeName))")
        case .component:
            return ClientBundleID("component-\(stableHashHex(component.typeName))")
        case .named(let name):
            return ClientBundleID("named-\(stableBundleName(name))")
        case .shared(let name):
            return ClientBundleID("shared-\(stableBundleName(name))")
        }
    }

    private func wasmRuntimeTargets(
        appProductName: String,
        for clientComponents: [ClientComponentDeclaration]
    ) -> [WasmRuntimeTargetDeclaration] {
        guard !clientComponents.isEmpty else {
            return []
        }

        let mainTargetName = "\(appProductName)WasmRuntime"
        let mainBundleID = ClientBundleID(Self.productName(forWasmRuntimeTarget: mainTargetName))
        var targets: [WasmRuntimeTargetDeclaration] = [
            WasmRuntimeTargetDeclaration(
                targetName: mainTargetName,
                bundleID: mainBundleID,
                componentTypeNames: clientComponents
                    .filter { Self.resolvedBundleID(for: $0) == nil }
                    .map(\.typeName)
            ),
        ]

        let splitComponents = Dictionary(grouping: clientComponents.compactMap { component -> (ClientBundleID, ClientComponentDeclaration)? in
            guard let bundleID = Self.resolvedBundleID(for: component) else {
                return nil
            }
            return (bundleID, component)
        }) { item in
            item.0
        }

        var usedTargetNames = Set<String>()
        usedTargetNames.insert(mainTargetName)
        for bundleID in splitComponents.keys.sorted() {
            let components = splitComponents[bundleID, default: []].map(\.1).sorted { left, right in
                left.typeName < right.typeName
            }
            var targetName = Self.wasmRuntimeTargetName(forBundleID: bundleID)
            var suffix = 2
            while !usedTargetNames.insert(targetName).inserted {
                targetName = "\(Self.wasmRuntimeTargetName(forBundleID: bundleID))\(suffix)"
                suffix += 1
            }
            targets.append(WasmRuntimeTargetDeclaration(
                targetName: targetName,
                bundleID: bundleID,
                componentTypeNames: components.map(\.typeName)
            ))
        }
        return targets
    }

    private func removeGeneratedBuildDirectoryIfPackageChanged(
        in packageDirectory: URL,
        nextPackageSwift: String
    ) throws {
        let packageFile = packageDirectory.appendingPathComponent("Package.swift")
        guard FileManager.default.fileExists(atPath: packageFile.path) else {
            return
        }

        let currentPackageSwift = try String(contentsOf: packageFile, encoding: .utf8)
        guard currentPackageSwift != nextPackageSwift else {
            return
        }

        let buildDirectory = packageDirectory.appendingPathComponent(".build", isDirectory: true)
        if FileManager.default.fileExists(atPath: buildDirectory.path) {
            try FileManager.default.removeItem(at: buildDirectory)
        }
    }

    private func syncPackageResolved(
        to packageDirectory: URL,
        keepingIdentities identities: Set<String>? = nil
    ) throws {
        let sourceURL = appPackageDirectory.appendingPathComponent("Package.resolved")
        let destinationURL = packageDirectory.appendingPathComponent("Package.resolved")

        if FileManager.default.fileExists(atPath: sourceURL.path) {
            if let identities {
                let data = try filteredPackageResolvedData(from: sourceURL, keepingIdentities: identities)
                try writeDataIfChanged(data, to: destinationURL)
            } else {
                let data = try Data(contentsOf: sourceURL)
                try writeDataIfChanged(data, to: destinationURL)
            }
        } else if FileManager.default.fileExists(atPath: destinationURL.path) {
            try FileManager.default.removeItem(at: destinationURL)
        }
    }

    private func filteredPackageResolvedData(
        from sourceURL: URL,
        keepingIdentities identities: Set<String>
    ) throws -> Data {
        let data = try Data(contentsOf: sourceURL)
        guard let object = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw SwiftWebGeneratedPackageMaterializerError.invalidPackageResolved(sourceURL)
        }
        guard let pins = object["pins"] as? [[String: Any]] else {
            throw SwiftWebGeneratedPackageMaterializerError.invalidPackageResolved(sourceURL)
        }

        let filteredPins = pins.filter { pin in
            guard let identity = pin["identity"] as? String else {
                return false
            }
            return identities.contains(identity.lowercased())
        }
        let filteredObject: [String: Any] = [
            "pins": filteredPins,
            "version": object["version"] ?? 3,
        ]
        return try JSONSerialization.data(
            withJSONObject: filteredObject,
            options: [.prettyPrinted, .sortedKeys]
        )
    }

    private func writeServerGeneratedSources(
        appProductName: String,
        wasmRuntimeTargets: [WasmRuntimeTargetDeclaration]
    ) throws {
        try write(
            serverLauncherSwift(
                appProductName: appProductName,
                wasmRuntimeTargets: wasmRuntimeTargets,
                installsDevelopmentHooks: false
            ),
            to: "Sources/AppServerLauncher/ServerLauncher.swift",
            in: serverPackageDirectory
        )
    }

    private func writeDevGeneratedSources(
        appProductName: String,
        wasmRuntimeTargets: [WasmRuntimeTargetDeclaration]
    ) throws {
        try write(
            devLauncherSwift(appProductName: appProductName),
            to: "Sources/SwiftWebDevLauncher/DevLauncher.swift",
            in: devPackageDirectory
        )
        try write(
            serverLauncherSwift(
                appProductName: appProductName,
                wasmRuntimeTargets: wasmRuntimeTargets,
                installsDevelopmentHooks: true
            ),
            to: "Sources/AppDevelopmentServerLauncher/ServerLauncher.swift",
            in: devPackageDirectory
        )
    }

    private func writeWasmGeneratedSources(
        appProductName: String,
        wasmRuntimeTargets: [WasmRuntimeTargetDeclaration]
    ) throws {
        for target in wasmRuntimeTargets {
            try write(
                wasmEntrypointSwift(appProductName: appProductName, target: target),
                to: "Sources/\(target.targetName)/\(target.targetName).swift",
                in: wasmPackageDirectory
            )
        }
    }

    private func copyClientSources(appProductName: String, to packageDirectory: URL) throws {
        let sourceDirectory = appPackageDirectory
            .appendingPathComponent("Sources", isDirectory: true)
            .appendingPathComponent(appProductName, isDirectory: true)
        guard FileManager.default.fileExists(atPath: sourceDirectory.path) else {
            throw SwiftWebGeneratedPackageMaterializerError.clientSourceDirectoryNotFound(sourceDirectory)
        }

        let destinationDirectory = packageDirectory
            .appendingPathComponent("Sources", isDirectory: true)
            .appendingPathComponent(appProductName, isDirectory: true)
        try FileManager.default.createDirectory(
            at: destinationDirectory,
            withIntermediateDirectories: true
        )

        try mirrorDirectoryContents(
            from: sourceDirectory,
            to: destinationDirectory,
            relativePath: "",
            shouldSkip: isServerOnly(relativePath:)
        )
    }

    private func copyClientRuntimeSources(from swiftWebPackageDirectory: URL, to packageDirectory: URL) throws {
        for targetName in ["SwiftWebActors", "SwiftWebUI", "SwiftWebUIRuntime"] {
            let sourceDirectory = swiftWebPackageDirectory
                .appendingPathComponent("Sources", isDirectory: true)
                .appendingPathComponent(targetName, isDirectory: true)
            let destinationDirectory = packageDirectory
                .appendingPathComponent("Sources", isDirectory: true)
                .appendingPathComponent(targetName, isDirectory: true)
            try FileManager.default.createDirectory(
                at: destinationDirectory,
                withIntermediateDirectories: true
            )
            try mirrorDirectoryContents(
                from: sourceDirectory,
                to: destinationDirectory,
                relativePath: "",
                shouldSkip: { $0 == "README.md" }
            )
        }
    }

    private func mirrorDirectoryContents(
        from sourceDirectory: URL,
        to destinationDirectory: URL,
        relativePath: String,
        shouldSkip: (String) -> Bool
    ) throws {
        let children = try FileManager.default.contentsOfDirectory(
            at: sourceDirectory,
            includingPropertiesForKeys: [.isDirectoryKey],
            options: [.skipsHiddenFiles]
        )

        var expectedNames = Set<String>()
        for child in children {
            let relativeChildPath = relativePath.isEmpty
                ? child.lastPathComponent
                : "\(relativePath)/\(child.lastPathComponent)"
            guard !shouldSkip(relativeChildPath) else {
                continue
            }
            expectedNames.insert(child.lastPathComponent)

            let destination = destinationDirectory.appendingPathComponent(child.lastPathComponent)
            let values = try child.resourceValues(forKeys: [.isDirectoryKey])
            if values.isDirectory == true {
                try FileManager.default.createDirectory(
                    at: destination,
                    withIntermediateDirectories: true
                )
                try mirrorDirectoryContents(
                    from: child,
                    to: destination,
                    relativePath: relativeChildPath,
                    shouldSkip: shouldSkip
                )
            } else {
                try copyFileIfChanged(from: child, to: destination)
            }
        }

        let destinationChildren = try FileManager.default.contentsOfDirectory(
            at: destinationDirectory,
            includingPropertiesForKeys: nil,
            options: [.skipsHiddenFiles]
        )
        for child in destinationChildren where !expectedNames.contains(child.lastPathComponent) {
            try FileManager.default.removeItem(at: child)
        }
    }

    private func copyFileIfChanged(from source: URL, to destination: URL) throws {
        if FileManager.default.fileExists(atPath: destination.path) {
            let sourceData = try Data(contentsOf: source)
            try writeDataIfChanged(sourceData, to: destination)
            return
        }
        try FileManager.default.copyItem(at: source, to: destination)
    }

    private func writeDataIfChanged(_ data: Data, to url: URL) throws {
        if FileManager.default.fileExists(atPath: url.path) {
            let current = try Data(contentsOf: url)
            if current == data {
                return
            }
        }
        try data.write(to: url, options: [.atomic])
    }

    private func removeStaleWasmSourceTargets(keeping names: Set<String>) throws {
        let sourcesDirectory = wasmPackageDirectory.appendingPathComponent("Sources", isDirectory: true)
        guard FileManager.default.fileExists(atPath: sourcesDirectory.path) else {
            return
        }
        let children = try FileManager.default.contentsOfDirectory(
            at: sourcesDirectory,
            includingPropertiesForKeys: nil,
            options: [.skipsHiddenFiles]
        )
        for child in children where !names.contains(child.lastPathComponent) {
            try FileManager.default.removeItem(at: child)
        }
    }

    private func isServerOnly(relativePath: String) -> Bool {
        let firstComponent = relativePath.split(separator: "/", maxSplits: 1).first.map(String.init)
        if firstComponent == "Actions" || firstComponent == "Routes" {
            return true
        }
        return relativePath == "App.swift"
    }

    private func write(_ contents: String, to relativePath: String, in packageDirectory: URL) throws {
        let url = packageDirectory.appendingPathComponent(relativePath)
        try FileManager.default.createDirectory(
            at: url.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        try writeIfChanged(contents, to: url)
    }

    private func writeIfChanged(_ contents: String, to url: URL) throws {
        if FileManager.default.fileExists(atPath: url.path) {
            let current = try String(contentsOf: url, encoding: .utf8)
            if current == contents {
                return
            }
        }
        try contents.write(to: url, atomically: true, encoding: .utf8)
    }

    private func serverLauncherSwift(
        appProductName: String,
        wasmRuntimeTargets: [WasmRuntimeTargetDeclaration],
        installsDevelopmentHooks: Bool
    ) -> String {
        let developmentImport = installsDevelopmentHooks
            ? "\nimport SwiftWebDevelopment"
            : ""
        let developmentInstall = installsDevelopmentHooks
            ? "\n        await SwiftWebDevelopment.install()\n"
            : ""
        guard let runtimeTarget = wasmRuntimeTargets.first else {
            return """
            import \(appProductName)\(developmentImport)

            @main
            struct AppServerLauncher {
                static func main() async throws {
            \(developmentInstall)        try await \(appProductName).run()
                }
            }
            """
        }

        let productName = Self.productName(forWasmRuntimeTarget: runtimeTarget.targetName)
        let assetPath = Self.assetPath(forWasmRuntimeTarget: runtimeTarget.targetName)
        let wasmPackageManifestPath = wasmPackageDirectory
            .appendingPathComponent("Package.swift")
            .path
        let additionalBundles = wasmRuntimeTargets.dropFirst().map { target in
            let componentTypeNames = target.componentTypeNames
                .map { "\"\(Self.swiftStringLiteral($0))\"" }
                .joined(separator: ", ")
            return """
                                ClientWasmBundleArtifact(
                                    id: "\(target.bundleID.rawValue)",
                                    componentTypeNames: [\(componentTypeNames)],
                                    assetPath: "\(Self.assetPath(forWasmRuntimeTarget: target.targetName))",
                                    artifact: SwiftPMWasmArtifact.location(
                                        anchorFile: "\(Self.swiftStringLiteral(wasmPackageManifestPath))",
                                        target: "\(target.targetName)",
                                        scratchDirectory: wasmScratchDirectory
                                    )
                                )
            """
        }
        .joined(separator: ",\n")
        let additionalBundlesArgument = additionalBundles.isEmpty
            ? "additionalBundles: []"
            : "additionalBundles: [\n\(additionalBundles)\n                            ]"
        return """
        import \(appProductName)
        import Foundation
        import SwiftWeb\(developmentImport)

        @main
        struct AppServerLauncher {
            static func main() async throws {
        \(developmentInstall)        let wasmScratchDirectory = ProcessInfo.processInfo.environment["SWIFTWEB_WASM_SCRATCH_PATH"].map {
                    URL(fileURLWithPath: $0, isDirectory: true)
                }

                try await \(appProductName).run(
                    clientRuntime: .wasm(
                        id: "\(productName)",
                        assetPath: "\(assetPath)",
                        artifact: SwiftPMWasmArtifact.location(
                            anchorFile: "\(Self.swiftStringLiteral(wasmPackageManifestPath))",
                            target: "\(runtimeTarget.targetName)",
                            scratchDirectory: wasmScratchDirectory
                        ),
                        \(additionalBundlesArgument),
                        metricsMode: .detailed
                    )
                )
            }
        }
        """
    }

    private func devLauncherSwift(appProductName: String) -> String {
        """
        import \(appProductName)
        import Foundation
        import SwiftWebDevelopment

        @main
        struct SwiftWebDevLauncher {
            static func main() throws {
                let environment = ProcessInfo.processInfo.environment
                let appPackagePath = environment["SWIFT_WEB_APP_PACKAGE_PATH"] ?? "\(Self.swiftStringLiteral(appPackageDirectory.path))"
                let product = environment["SWIFT_WEB_DEV_PRODUCT"] ?? "\(Self.swiftStringLiteral(developmentServerProductName))"
                let host = environment["SWIFT_WEB_DEV_HOST"] ?? "127.0.0.1"
                let port = try integerEnvironment("SWIFT_WEB_DEV_PORT", in: environment, defaultValue: 3000)

                let configuration = SwiftWebDevRuntimeConfiguration(
                    packageDirectory: URL(fileURLWithPath: appPackagePath),
                    product: product,
                    host: host,
                    port: port
                )
                try SwiftWebDevRuntime(configuration: configuration).run()
            }

            private static func integerEnvironment(
                _ key: String,
                in environment: [String: String],
                defaultValue: Int
            ) throws -> Int {
                guard let rawValue = environment[key] else {
                    return defaultValue
                }
                guard let value = Int(rawValue) else {
                    throw SwiftWebDevLauncherError.invalidIntegerEnvironment(key: key, value: rawValue)
                }
                return value
            }
        }

        enum SwiftWebDevLauncherError: Error, CustomStringConvertible {
            case invalidIntegerEnvironment(key: String, value: String)

            var description: String {
                switch self {
                case .invalidIntegerEnvironment(let key, let value):
                    return "\\(key) must be an integer, but got \\(value)"
                }
            }
        }
        """
    }

    private func serverPackageSwift(
        appPackageName: String,
        appPackageDependencyName: String,
        appProductName: String
    ) -> String {
        return """
        // swift-tools-version: 6.3

        import PackageDescription

        let swiftSettings: [SwiftSetting] = [
            .enableUpcomingFeature("ApproachableConcurrency"),
        ]

        let appServerTarget = Target.executableTarget(
            name: "AppServerLauncher",
            dependencies: [
                .product(name: "\(appProductName)", package: "\(appPackageDependencyName)"),
            ],
            path: "Sources/AppServerLauncher",
            swiftSettings: swiftSettings
        )

        let package = Package(
            name: "\(appPackageName)ServerGenerated",
            platforms: [
                .macOS("26.2"),
            ],
            products: [
                .executable(name: "\(serverProductName)", targets: ["AppServerLauncher"]),
            ],
            dependencies: [
                .package(path: "\(Self.swiftStringLiteral(appPackageDirectory.path))"),
            ],
            targets: [
                appServerTarget,
            ],
            swiftLanguageModes: [.v6]
        )
        """
    }

    private func devPackageSwift(
        appPackageName: String,
        appPackageDependencyName: String,
        appProductName: String,
        developmentServerProductName: String,
        devProductName: String,
        swiftWebPackageDirectory: URL
    ) -> String {
        return """
        // swift-tools-version: 6.3

        import PackageDescription

        let swiftSettings: [SwiftSetting] = [
            .enableUpcomingFeature("ApproachableConcurrency"),
        ]

        let swiftWebDevLauncherTarget = Target.executableTarget(
            name: "SwiftWebDevLauncher",
            dependencies: [
                .product(name: "\(appProductName)", package: "\(appPackageDependencyName)"),
                .product(name: "SwiftWebDevelopment", package: "swift-web"),
            ],
            path: "Sources/SwiftWebDevLauncher",
            swiftSettings: swiftSettings
        )

        let appDevelopmentServerTarget = Target.executableTarget(
            name: "AppDevelopmentServerLauncher",
            dependencies: [
                .product(name: "\(appProductName)", package: "\(appPackageDependencyName)"),
                .product(name: "SwiftWeb", package: "swift-web"),
                .product(name: "SwiftWebDevelopment", package: "swift-web"),
            ],
            path: "Sources/AppDevelopmentServerLauncher",
            swiftSettings: swiftSettings
        )

        let package = Package(
            name: "\(appPackageName)DevGenerated",
            platforms: [
                .macOS("26.2"),
            ],
            products: [
                .executable(name: "\(devProductName)", targets: ["SwiftWebDevLauncher"]),
                .executable(name: "\(developmentServerProductName)", targets: ["AppDevelopmentServerLauncher"]),
            ],
            dependencies: [
                .package(path: "\(Self.swiftStringLiteral(appPackageDirectory.path))"),
                .package(path: "\(Self.swiftStringLiteral(swiftWebPackageDirectory.path))"),
            ],
            targets: [
                swiftWebDevLauncherTarget,
                appDevelopmentServerTarget,
            ],
            swiftLanguageModes: [.v6]
        )
        """
    }

    private func wasmPackageSwift(
        appPackageName: String,
        appProductName: String,
        swiftHTMLPackageDirectory: URL?,
        wasmRuntimeTargetNames: [String]
    ) -> String {
        let wasmTargetDeclarations = wasmRuntimeTargetNames.map { targetName in
            wasmRuntimeTargetDeclaration(targetName: targetName, appProductName: appProductName)
        }
        .joined(separator: "\n\n")
        let wasmProductDeclarations = wasmRuntimeTargetNames
            .map { targetName in
                ".executable(name: \"\(Self.productName(forWasmRuntimeTarget: targetName))\", targets: [\"\(targetName)\"])"
            }
            .joined(separator: ",\n        ")
        let wasmTargets = (["appClientTarget"] + wasmRuntimeTargetNames.map(Self.variableName(for:)))
            .map { "        \($0)" }
            .joined(separator: ",\n")
        let swiftHTMLPackageDependency = swiftHTMLPackageDirectory.map {
            ".package(path: \"\(Self.swiftStringLiteral($0.path))\")"
        } ?? ".package(url: \"https://github.com/1amageek/swift-html.git\", from: \"0.3.0\")"
        return """
        // swift-tools-version: 6.3

        import PackageDescription

        let swiftSettings: [SwiftSetting] = [
            .enableUpcomingFeature("ApproachableConcurrency"),
        ]
        let wasmSwiftSettings: [SwiftSetting] = swiftSettings + [
            .unsafeFlags(["-Xclang-linker", "-mexec-model=reactor"]),
        ]
        let wasmLinkerSettings: [LinkerSetting] = [
            .unsafeFlags([
                "-Xlinker", "--export=swiftweb_alloc",
                "-Xlinker", "--export=swiftweb_dealloc",
                "-Xlinker", "--export=swiftweb_bootstrap",
                "-Xlinker", "--export=swiftweb_dispatch_event",
                "-Xlinker", "--export=swiftweb_snapshot_state",
                "-Xlinker", "--export=swiftweb_restore_state",
                "-Xlinker", "--export=swiftweb_response_ptr",
                "-Xlinker", "--export=swiftweb_response_len",
                "-Xlinker", "--export=swiftweb_response_free",
            ]),
        ]

        let appClientTarget = Target.target(
            name: "\(appProductName)",
            dependencies: [
                .product(name: "SwiftHTML", package: "swift-html"),
                "SwiftWebActors",
                "SwiftWebUI",
            ],
            path: "Sources/\(appProductName)",
            swiftSettings: swiftSettings
        )

        let swiftWebActorsTarget = Target.target(
            name: "SwiftWebActors",
            dependencies: [
                .product(name: "ActorRuntime", package: "swift-actor-runtime"),
            ],
            path: "Sources/SwiftWebActors",
            swiftSettings: swiftSettings
        )

        let swiftWebUITarget = Target.target(
            name: "SwiftWebUI",
            dependencies: [
                .product(name: "SwiftHTML", package: "swift-html"),
            ],
            path: "Sources/SwiftWebUI",
            swiftSettings: swiftSettings
        )

        let swiftWebUIRuntimeTarget = Target.target(
            name: "SwiftWebUIRuntime",
            dependencies: [
                .product(name: "SwiftHTML", package: "swift-html"),
                .product(name: "JavaScriptKit", package: "JavaScriptKit"),
                "SwiftWebActors",
            ],
            path: "Sources/SwiftWebUIRuntime",
            swiftSettings: swiftSettings
        )

        \(wasmTargetDeclarations)

        let package = Package(
            name: "\(appPackageName)WasmGenerated",
            platforms: [
                .macOS("26.2"),
            ],
            products: [
                \(wasmProductDeclarations)
            ],
            dependencies: [
                \(swiftHTMLPackageDependency),
                .package(url: "https://github.com/swiftwasm/JavaScriptKit.git", from: "0.55.0"),
                .package(url: "https://github.com/1amageek/swift-actor-runtime.git", exact: "0.5.0"),
            ],
            targets: [
                swiftWebActorsTarget,
                swiftWebUITarget,
                swiftWebUIRuntimeTarget,
        \(wasmTargets)
            ],
            swiftLanguageModes: [.v6]
        )
        """
    }

    private func wasmRuntimeTargetDeclaration(targetName: String, appProductName: String) -> String {
        """
        let \(Self.variableName(for: targetName)) = Target.executableTarget(
            name: "\(targetName)",
            dependencies: [
                "\(appProductName)",
                "SwiftWebActors",
                .product(name: "SwiftHTML", package: "swift-html"),
                "SwiftWebUI",
                "SwiftWebUIRuntime",
            ],
            path: "Sources/\(targetName)",
            swiftSettings: wasmSwiftSettings,
            linkerSettings: wasmLinkerSettings
        )
        """
    }

    private static func productName(forWasmRuntimeTarget targetName: String) -> String {
        kebabCase(targetName)
    }

    private static func assetPath(forWasmRuntimeTarget targetName: String) -> String {
        "/assets/\(productName(forWasmRuntimeTarget: targetName)).wasm"
    }

    private static func wasmRuntimeTargetName(forClientComponent componentTypeName: String) -> String {
        if componentTypeName.hasPrefix("Client") {
            let suffix = componentTypeName.dropFirst("Client".count)
            if !suffix.isEmpty {
                return "\(suffix)WasmRuntime"
            }
        }
        if componentTypeName.hasSuffix("Component") {
            return "\(componentTypeName.dropLast("Component".count))WasmRuntime"
        }
        return "\(componentTypeName)WasmRuntime"
    }

    private static func wasmRuntimeTargetName(forBundleID bundleID: ClientBundleID) -> String {
        let parts = bundleID.rawValue
            .split(separator: "-")
            .map { part in
                part.prefix(1).uppercased() + part.dropFirst()
            }
            .joined()
        return "\(parts)WasmRuntime"
    }

    private static func variableName(for targetName: String) -> String {
        let first = targetName.prefix(1).lowercased()
        let rest = targetName.dropFirst()
        return "\(first)\(rest)Target"
    }

    private static func kebabCase(_ value: String) -> String {
        var output = ""
        for scalar in value.unicodeScalars {
            let character = Character(scalar)
            if CharacterSet.uppercaseLetters.contains(scalar) {
                if !output.isEmpty {
                    output.append("-")
                }
                output.append(String(character).lowercased())
            } else {
                output.append(String(character))
            }
        }
        return output
    }

    private static func stableBundleName(_ value: String) -> String {
        let allowed = value.unicodeScalars.map { scalar -> Character in
            if CharacterSet.alphanumerics.contains(scalar)
                || scalar.value == 45
                || scalar.value == 95 {
                return Character(scalar)
            }
            return "-"
        }
        let rawName = String(allowed)
            .split(separator: "-")
            .joined(separator: "-")
            .lowercased()
        guard !rawName.isEmpty else {
            return stableHashHex(value)
        }
        return rawName
    }

    private static func stableHashHex(_ value: String) -> String {
        var hash: UInt64 = 14_695_981_039_346_656_037
        for byte in value.utf8 {
            hash ^= UInt64(byte)
            hash &*= 1_099_511_628_211
        }
        return String(hash, radix: 16)
    }

    private static func localPackageIdentity(for packageDirectory: URL) -> String {
        packageDirectory
            .lastPathComponent
            .lowercased()
    }

    private static func swiftStringLiteral(_ value: String) -> String {
        value
            .replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "\"", with: "\\\"")
            .replacingOccurrences(of: "\n", with: "\\n")
            .replacingOccurrences(of: "\r", with: "\\r")
    }

    private func wasmEntrypointSwift(
        appProductName: String,
        target: WasmRuntimeTargetDeclaration
    ) -> String {
        let runtimeVariableName = "\(Self.lowerCamelCase(target.targetName))Runtime"
        let registrations = target.componentTypeNames.map { typeName in
            """
                ClientWasmComponentRegistration(
                    \(typeName).self,
                    environmentRegistry: .swiftWebUI
                ) { _ in
                    \(typeName)()
                }
            """
        }
        .joined(separator: ",\n")
        return """
        import \(appProductName)
        import SwiftHTML
        import SwiftWebUI
        import SwiftWebUIRuntime

        nonisolated(unsafe) private let \(runtimeVariableName) = ClientWasmBundleRuntimeEntrypoint(
            registrations: [
        \(registrations)
            ]
        )

        @_cdecl("swiftweb_alloc")
        public func swiftweb_alloc(_ byteCount: UInt32) -> UInt32 {
            \(runtimeVariableName).allocate(byteCount: byteCount)
        }

        @_cdecl("swiftweb_dealloc")
        public func swiftweb_dealloc(_ pointer: UInt32, _ byteCount: UInt32) {
            \(runtimeVariableName).deallocate(pointer: pointer, byteCount: byteCount)
        }

        @_cdecl("swiftweb_bootstrap")
        public func swiftweb_bootstrap(_ pointer: UInt32, _ length: UInt32) -> UInt32 {
            \(runtimeVariableName).bootstrap(pointer: pointer, length: length)
        }

        @_cdecl("swiftweb_dispatch_event")
        public func swiftweb_dispatch_event(_ pointer: UInt32, _ length: UInt32) -> UInt32 {
            \(runtimeVariableName).dispatchEvent(pointer: pointer, length: length)
        }

        @_cdecl("swiftweb_snapshot_state")
        public func swiftweb_snapshot_state() -> UInt32 {
            \(runtimeVariableName).snapshotState()
        }

        @_cdecl("swiftweb_restore_state")
        public func swiftweb_restore_state(_ pointer: UInt32, _ length: UInt32) -> UInt32 {
            \(runtimeVariableName).restoreState(pointer: pointer, length: length)
        }

        @_cdecl("swiftweb_response_ptr")
        public func swiftweb_response_ptr() -> UInt32 {
            \(runtimeVariableName).responsePointer()
        }

        @_cdecl("swiftweb_response_len")
        public func swiftweb_response_len() -> UInt32 {
            \(runtimeVariableName).responseLength()
        }

        @_cdecl("swiftweb_response_free")
        public func swiftweb_response_free() {
            \(runtimeVariableName).freeResponse()
        }

        @main
        struct \(target.targetName)Main {
            static func main() {}
        }
        """
    }

    private static func lowerCamelCase(_ value: String) -> String {
        guard let first = value.first else {
            return value
        }
        return first.lowercased() + String(value.dropFirst())
    }
}

private struct ClientComponentDeclaration: Sendable {
    let typeName: String
    var loadPolicy: LoadPolicy
    var bundlePolicy: BundlePolicy

    init(
        typeName: String,
        loadPolicy: LoadPolicy = .eager,
        bundlePolicy: BundlePolicy = .main
    ) {
        self.typeName = typeName
        self.loadPolicy = loadPolicy
        self.bundlePolicy = bundlePolicy
    }

    func merged(with other: ClientComponentDeclaration) -> ClientComponentDeclaration {
        ClientComponentDeclaration(
            typeName: typeName,
            loadPolicy: other.loadPolicy != .eager ? other.loadPolicy : loadPolicy,
            bundlePolicy: other.bundlePolicy != .main ? other.bundlePolicy : bundlePolicy
        )
    }
}

private struct WasmRuntimeTargetDeclaration: Sendable {
    let targetName: String
    let bundleID: ClientBundleID
    let componentTypeNames: [String]

    var componentTypeName: String {
        componentTypeNames.first ?? targetName
    }
}
