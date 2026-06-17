import Darwin
import Foundation

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

    public func materialize() throws -> SwiftWebGeneratedPackage {
        let packageName = try SwiftWebPackageManifestInspector.packageName(in: appPackageDirectory)
        let appProductName = appProductName ?? packageName
        let devProductName = devProductName ?? packageName
        let swiftWebPackageDirectory = try SwiftWebPackageManifestInspector.localDependencyRoot(
            named: "swift-web",
            in: appPackageDirectory
        )
        try FileManager.default.createDirectory(
            at: generatedPackageDirectory,
            withIntermediateDirectories: true
        )
        return try withMaterializationLock {
            try materializeUnlocked(
                packageName: packageName,
                appProductName: appProductName,
                devProductName: devProductName,
                swiftWebPackageDirectory: swiftWebPackageDirectory
            )
        }
    }

    private func materializeUnlocked(
        packageName: String,
        appProductName: String,
        devProductName: String,
        swiftWebPackageDirectory: URL
    ) throws -> SwiftWebGeneratedPackage {
        let clientComponents = try discoverClientComponents(appProductName: appProductName)
        let wasmRuntimeTargets = wasmRuntimeTargets(for: clientComponents)
        let wasmRuntimeTargetNames = wasmRuntimeTargets.map(\.targetName)
        let wasmProductNames = wasmRuntimeTargetNames.map(Self.productName(forWasmRuntimeTarget:))
        let wasmRuntimes = wasmRuntimeTargets.map { target in
            SwiftWebGeneratedWasmRuntime(
                targetName: target.targetName,
                productName: Self.productName(forWasmRuntimeTarget: target.targetName),
                componentTypeName: target.componentTypeName,
                assetPath: Self.assetPath(forWasmRuntimeTarget: target.targetName)
            )
        }

        try removeLegacyMaterializationLockFile()
        try removeGeneratedRuntimeSources()
        try writeGeneratedSources(appProductName: appProductName, wasmRuntimeTargets: wasmRuntimeTargets)
        try copyClientSources(appProductName: appProductName)
        try copyClientRuntimeSources(from: swiftWebPackageDirectory)
        let packageSwiftContents = packageSwift(
            appPackageName: packageName,
            appPackageDependencyName: Self.localPackageIdentity(for: appPackageDirectory),
            appProductName: appProductName,
            devProductName: devProductName,
            swiftWebPackageDirectory: swiftWebPackageDirectory,
            wasmRuntimeTargetNames: wasmRuntimeTargetNames
        )
        try removeGeneratedBuildDirectoryIfPackageChanged(nextPackageSwift: packageSwiftContents)
        try packageSwiftContents.write(
            to: generatedPackageDirectory.appendingPathComponent("Package.swift"),
            atomically: true,
            encoding: .utf8
        )

        return SwiftWebGeneratedPackage(
            appPackageDirectory: appPackageDirectory,
            packageDirectory: generatedPackageDirectory,
            swiftWebPackageDirectory: swiftWebPackageDirectory,
            appProductName: appProductName,
            serverProductName: serverProductName,
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

    private func discoverClientComponents(appProductName: String) throws -> [ClientComponentDeclaration] {
        let sourceDirectory = appPackageDirectory
            .appendingPathComponent("Sources", isDirectory: true)
            .appendingPathComponent(appProductName, isDirectory: true)
        guard FileManager.default.fileExists(atPath: sourceDirectory.path) else {
            throw SwiftWebGeneratedPackageMaterializerError.clientSourceDirectoryNotFound(sourceDirectory)
        }

        let componentNames = try collectSwiftFiles(
            in: sourceDirectory,
            relativePath: ""
        )
        .flatMap { file in
            try Self.clientComponentNames(in: file.url, relativePath: file.relativePath)
        }

        var seen = Set<String>()
        return componentNames
            .filter { seen.insert($0).inserted }
            .sorted()
            .map(ClientComponentDeclaration.init(typeName:))
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

    private static func clientComponentNames(in file: URL, relativePath: String) throws -> [String] {
        let source = try String(contentsOf: file, encoding: .utf8)
        let pattern = #"(?:public\s+)?(?:struct|final\s+class|class)\s+([A-Za-z_][A-Za-z0-9_]*)\s*(?:<[^>{}]+>)?\s*:\s*([^{]+)"#
        let regex = try NSRegularExpression(pattern: pattern)
        let range = NSRange(source.startIndex..<source.endIndex, in: source)

        return regex.matches(in: source, range: range).compactMap { match in
            guard match.numberOfRanges > 2,
                  let nameRange = Range(match.range(at: 1), in: source),
                  let conformancesRange = Range(match.range(at: 2), in: source)
            else {
                return nil
            }
            let conformances = source[conformancesRange]
            guard conformances.contains("ClientComponent") else {
                return nil
            }
            return String(source[nameRange])
        }
    }

    private func wasmRuntimeTargets(
        for clientComponents: [ClientComponentDeclaration]
    ) -> [WasmRuntimeTargetDeclaration] {
        var usedTargetNames = Set<String>()
        return clientComponents.map { component in
            var targetName = Self.wasmRuntimeTargetName(forClientComponent: component.typeName)
            var suffix = 2
            while !usedTargetNames.insert(targetName).inserted {
                targetName = "\(Self.wasmRuntimeTargetName(forClientComponent: component.typeName))\(suffix)"
                suffix += 1
            }
            return WasmRuntimeTargetDeclaration(
                targetName: targetName,
                componentTypeName: component.typeName
            )
        }
    }

    private func removeGeneratedRuntimeSources() throws {
        let sourcesDirectory = generatedPackageDirectory.appendingPathComponent(
            "Sources",
            isDirectory: true
        )
        guard FileManager.default.fileExists(atPath: sourcesDirectory.path) else {
            return
        }

        let children = try FileManager.default.contentsOfDirectory(
            at: sourcesDirectory,
            includingPropertiesForKeys: [.isDirectoryKey],
            options: [.skipsHiddenFiles]
        )

        for child in children {
            let values = try child.resourceValues(forKeys: [.isDirectoryKey])
            guard values.isDirectory == true else {
                continue
            }
            let name = child.lastPathComponent
            let isWasmRuntime = name.hasSuffix("WasmRuntime")
            let isOldServerLauncher = name.hasSuffix("ServerLauncher") && name != "AppServerLauncher"
            let isOldDevLauncher = name.hasSuffix("DevLauncher") && name != "SwiftWebDevLauncher"
            if isWasmRuntime || isOldServerLauncher || isOldDevLauncher {
                try FileManager.default.removeItem(at: child)
            }
        }
    }

    private func removeGeneratedBuildDirectoryIfPackageChanged(nextPackageSwift: String) throws {
        let packageFile = generatedPackageDirectory.appendingPathComponent("Package.swift")
        guard FileManager.default.fileExists(atPath: packageFile.path) else {
            return
        }

        let currentPackageSwift = try String(contentsOf: packageFile, encoding: .utf8)
        guard currentPackageSwift != nextPackageSwift else {
            return
        }

        let buildDirectory = generatedPackageDirectory.appendingPathComponent(".build", isDirectory: true)
        if FileManager.default.fileExists(atPath: buildDirectory.path) {
            try FileManager.default.removeItem(at: buildDirectory)
        }
    }

    private func writeGeneratedSources(
        appProductName: String,
        wasmRuntimeTargets: [WasmRuntimeTargetDeclaration]
    ) throws {
        try write(
            serverLauncherSwift(appProductName: appProductName, wasmRuntimeTargets: wasmRuntimeTargets),
            to: "Sources/AppServerLauncher/ServerLauncher.swift"
        )
        try write(
            devLauncherSwift(appProductName: appProductName),
            to: "Sources/SwiftWebDevLauncher/DevLauncher.swift"
        )
        for target in wasmRuntimeTargets {
            try write(
                wasmEntrypointSwift(appProductName: appProductName, target: target),
                to: "Sources/\(target.targetName)/\(target.targetName).swift"
            )
        }
    }

    private func copyClientSources(appProductName: String) throws {
        let sourceDirectory = appPackageDirectory
            .appendingPathComponent("Sources", isDirectory: true)
            .appendingPathComponent(appProductName, isDirectory: true)
        guard FileManager.default.fileExists(atPath: sourceDirectory.path) else {
            throw SwiftWebGeneratedPackageMaterializerError.clientSourceDirectoryNotFound(sourceDirectory)
        }

        let destinationDirectory = generatedPackageDirectory
            .appendingPathComponent("Sources", isDirectory: true)
            .appendingPathComponent(appProductName, isDirectory: true)
        if FileManager.default.fileExists(atPath: destinationDirectory.path) {
            try FileManager.default.removeItem(at: destinationDirectory)
        }
        try FileManager.default.createDirectory(
            at: destinationDirectory,
            withIntermediateDirectories: true
        )

        try copyDirectoryContents(
            from: sourceDirectory,
            to: destinationDirectory,
            relativePath: "",
            shouldSkip: isServerOnly(relativePath:)
        )
    }

    private func copyClientRuntimeSources(from swiftWebPackageDirectory: URL) throws {
        for targetName in ["SwiftWebActors", "SwiftWebUI", "SwiftWebUIRuntime"] {
            let sourceDirectory = swiftWebPackageDirectory
                .appendingPathComponent("Sources", isDirectory: true)
                .appendingPathComponent(targetName, isDirectory: true)
            let destinationDirectory = generatedPackageDirectory
                .appendingPathComponent("Sources", isDirectory: true)
                .appendingPathComponent(targetName, isDirectory: true)
            if FileManager.default.fileExists(atPath: destinationDirectory.path) {
                try FileManager.default.removeItem(at: destinationDirectory)
            }
            try FileManager.default.createDirectory(
                at: destinationDirectory,
                withIntermediateDirectories: true
            )
            try copyDirectoryContents(
                from: sourceDirectory,
                to: destinationDirectory,
                relativePath: "",
                shouldSkip: { $0 == "README.md" }
            )
        }
    }

    private func copyDirectoryContents(
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

        for child in children {
            let relativeChildPath = relativePath.isEmpty
                ? child.lastPathComponent
                : "\(relativePath)/\(child.lastPathComponent)"
            guard !shouldSkip(relativeChildPath) else {
                continue
            }

            let destination = destinationDirectory.appendingPathComponent(child.lastPathComponent)
            let values = try child.resourceValues(forKeys: [.isDirectoryKey])
            if values.isDirectory == true {
                try FileManager.default.createDirectory(
                    at: destination,
                    withIntermediateDirectories: true
                )
                try copyDirectoryContents(
                    from: child,
                    to: destination,
                    relativePath: relativeChildPath,
                    shouldSkip: shouldSkip
                )
            } else {
                try FileManager.default.copyItem(at: child, to: destination)
            }
        }
    }

    private func isServerOnly(relativePath: String) -> Bool {
        let firstComponent = relativePath.split(separator: "/", maxSplits: 1).first.map(String.init)
        if firstComponent == "Actions" || firstComponent == "Routes" {
            return true
        }
        return relativePath == "App.swift"
    }

    private func write(_ contents: String, to relativePath: String) throws {
        let url = generatedPackageDirectory.appendingPathComponent(relativePath)
        try FileManager.default.createDirectory(
            at: url.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        try contents.write(to: url, atomically: true, encoding: .utf8)
    }

    private func serverLauncherSwift(
        appProductName: String,
        wasmRuntimeTargets: [WasmRuntimeTargetDeclaration]
    ) -> String {
        guard let runtimeTarget = wasmRuntimeTargets.first else {
            return """
            import \(appProductName)

            @main
            struct AppServerLauncher {
                static func main() async throws {
                    try await \(appProductName).run()
                }
            }
            """
        }

        let productName = Self.productName(forWasmRuntimeTarget: runtimeTarget.targetName)
        let assetPath = Self.assetPath(forWasmRuntimeTarget: runtimeTarget.targetName)
        let additionalBundles = wasmRuntimeTargets.dropFirst().map { target in
            """
                                ClientWasmBundleArtifact(
                                    id: "\(Self.productName(forWasmRuntimeTarget: target.targetName))",
                                    componentTypeName: "\(target.componentTypeName)",
                                    assetPath: "\(Self.assetPath(forWasmRuntimeTarget: target.targetName))",
                                    artifact: SwiftPMWasmArtifact.location(
                                        anchorFile: #filePath,
                                        target: "\(target.targetName)"
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
        import SwiftWeb

        @main
        struct AppServerLauncher {
            static func main() async throws {
                try await \(appProductName).run(
                    clientRuntime: .wasm(
                        id: "\(productName)",
                        assetPath: "\(assetPath)",
                        artifact: SwiftPMWasmArtifact.location(
                            anchorFile: #filePath,
                            target: "\(runtimeTarget.targetName)"
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
        import SwiftWeb

        @main
        struct SwiftWebDevLauncher {
            static func main() throws {
                let environment = ProcessInfo.processInfo.environment
                let appPackagePath = environment["SWIFT_WEB_APP_PACKAGE_PATH"] ?? "\(Self.swiftStringLiteral(appPackageDirectory.path))"
                let product = environment["SWIFT_WEB_DEV_PRODUCT"] ?? "\(Self.swiftStringLiteral(serverProductName))"
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

    private func packageSwift(
        appPackageName: String,
        appPackageDependencyName: String,
        appProductName: String,
        devProductName: String,
        swiftWebPackageDirectory: URL,
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
        let nonWasmTargets = [
            "appServerTarget",
            "swiftWebDevLauncherTarget",
        ]
        .map { "        \($0)" }
        .joined(separator: ",\n")
        let wasmTargets = (["appClientTarget"] + wasmRuntimeTargetNames.map(Self.variableName(for:)))
            .map { "        \($0)" }
            .joined(separator: ",\n")
        return """
        // swift-tools-version: 6.3

        import PackageDescription

        let buildsWasmRuntime = Context.environment["SWIFTWEB_WASM_BUILD"] == "1"
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

        let appServerTarget = Target.executableTarget(
            name: "AppServerLauncher",
            dependencies: [
                .product(name: "\(appProductName)", package: "\(appPackageDependencyName)"),
            ],
            path: "Sources/AppServerLauncher",
            swiftSettings: swiftSettings
        )

        let swiftWebDevLauncherTarget = Target.executableTarget(
            name: "SwiftWebDevLauncher",
            dependencies: [
                .product(name: "\(appProductName)", package: "\(appPackageDependencyName)"),
                .product(name: "SwiftWeb", package: "swift-web"),
            ],
            path: "Sources/SwiftWebDevLauncher",
            swiftSettings: swiftSettings
        )

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
            name: "\(appPackageName)Generated",
            platforms: [
                .macOS("26.2"),
            ],
            products: buildsWasmRuntime ? [
                \(wasmProductDeclarations)
            ] : [
                .executable(name: "\(devProductName)", targets: ["SwiftWebDevLauncher"]),
                .executable(name: "\(serverProductName)", targets: ["AppServerLauncher"]),
            ],
            dependencies: buildsWasmRuntime ? [
                .package(url: "https://github.com/1amageek/swift-html.git", from: "0.2.2"),
                .package(url: "https://github.com/swiftwasm/JavaScriptKit.git", from: "0.55.0"),
                .package(url: "https://github.com/1amageek/swift-actor-runtime.git", exact: "0.5.0"),
            ] : [
                .package(path: "\(Self.swiftStringLiteral(appPackageDirectory.path))"),
                .package(path: "\(Self.swiftStringLiteral(swiftWebPackageDirectory.path))"),
            ],
            targets: buildsWasmRuntime ? [
                swiftWebActorsTarget,
                swiftWebUITarget,
                swiftWebUIRuntimeTarget,
        \(wasmTargets)
            ] : [
        \(nonWasmTargets)
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
        let runtimeVariableName = "\(Self.lowerCamelCase(target.componentTypeName))Runtime"
        return """
        import \(appProductName)
        import SwiftHTML
        import SwiftWebUI
        import SwiftWebUIRuntime

        nonisolated(unsafe) private let \(runtimeVariableName) = ClientWasmRuntimeEntrypoint(
            environmentRegistry: .swiftWebUI,
            componentMount: ClientWasmComponentMount(\(target.componentTypeName).self)
        ) { _ in
            \(target.componentTypeName)()
        }

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
}

private struct WasmRuntimeTargetDeclaration: Sendable {
    let targetName: String
    let componentTypeName: String
}
