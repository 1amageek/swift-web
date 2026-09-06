import Foundation

struct SwiftPackageDependencyGraph: Decodable, Sendable {
    struct Package: Decodable, Sendable {
        let identity: String
        let name: String
        let url: String
        let version: String
        let path: String
        let revision: String?
        let dependencies: [Package]

        init(
            identity: String,
            name: String,
            url: String,
            version: String,
            path: String,
            revision: String? = nil,
            dependencies: [Package]
        ) {
            self.identity = identity
            self.name = name
            self.url = url
            self.version = version
            self.path = path
            self.revision = revision
            self.dependencies = dependencies
        }

        var directory: URL {
            URL(fileURLWithPath: path, isDirectory: true).standardizedFileURL
        }

        func applyingResolvedRevisions(_ revisions: [String: String]) -> Package {
            Package(
                identity: identity,
                name: name,
                url: url,
                version: version,
                path: path,
                revision: revisions[identity] ?? revision,
                dependencies: dependencies.map { $0.applyingResolvedRevisions(revisions) }
            )
        }
    }

    let root: Package

    init(root: Package) {
        self.root = root
    }

    func applyingResolvedRevisions(from packageDirectory: URL) throws -> SwiftPackageDependencyGraph {
        let packageResolvedURL = packageDirectory
            .appendingPathComponent("Package.resolved")
        guard FileManager.default.fileExists(atPath: packageResolvedURL.path) else {
            return self
        }

        let pins: [PackageResolvedPin]
        do {
            pins = try JSONDecoder().decode(
                PackageResolved.self,
                from: Data(contentsOf: packageResolvedURL)
            ).pins
        } catch {
            throw SwiftWebLifecycleError.invalidPackageResolved(packageResolvedURL)
        }

        var revisions: [String: String] = [:]
        for pin in pins where pin.kind == "remoteSourceControl" {
            guard let revision = pin.state.revision else {
                continue
            }
            guard Self.isImmutableRevision(revision) else {
                throw SwiftWebLifecycleError.invalidPackageResolved(packageResolvedURL)
            }
            let identity = pin.identity
            guard !identity.isEmpty, revisions[identity] == nil else {
                throw SwiftWebLifecycleError.invalidPackageResolved(packageResolvedURL)
            }
            revisions[identity] = revision
        }

        return SwiftPackageDependencyGraph(
            root: root.applyingResolvedRevisions(revisions)
        )
    }

    private static func isImmutableRevision(_ value: String) -> Bool {
        value.utf8.count == 40 && value.utf8.allSatisfy { byte in
            (UInt8(ascii: "0")...UInt8(ascii: "9")).contains(byte)
                || (UInt8(ascii: "a")...UInt8(ascii: "f")).contains(byte)
                || (UInt8(ascii: "A")...UInt8(ascii: "F")).contains(byte)
        }
    }

    init(from decoder: Decoder) throws {
        root = try Package(from: decoder)
    }
}

private struct PackageResolved: Decodable {
    let pins: [PackageResolvedPin]
}

private struct PackageResolvedPin: Decodable {
    struct State: Decodable {
        let revision: String?
    }

    let identity: String
    let kind: String
    let state: State
}

protocol SwiftPackageDependencyGraphLoading: Sendable {
    func load(packageDirectory: URL) async throws -> SwiftPackageDependencyGraph
}

struct SwiftPackageDependencyGraphLoader: SwiftPackageDependencyGraphLoading {
    func load(packageDirectory: URL) async throws -> SwiftPackageDependencyGraph {
        let invocation = try SwiftBuildInvocation.host(packageDirectory: packageDirectory)
        let process = Process()
        let standardOutput = Pipe()
        process.executableURL = invocation.executableURL
        process.arguments = invocation.arguments(
            for: ["package", "show-dependencies", "--format", "json"]
        )
        process.environment = ProcessInfo.processInfo.environment.merging(
            ["SWIFTWEB_ADAPTER_DISCOVERY": "1"],
            uniquingKeysWith: { _, discoveryValue in discoveryValue }
        )
        process.currentDirectoryURL = packageDirectory
        process.standardOutput = standardOutput
        process.standardError = FileHandle.standardError

        let outputTask = Task.detached {
            try standardOutput.fileHandleForReading.readToEnd() ?? Data()
        }
        let status = try await SwiftWebLifecycleCommandRunner().run(process)
        let outputData = try await outputTask.value

        guard status == 0 else {
            let output = String(decoding: outputData, as: UTF8.self)
            throw SwiftWebLifecycleError.packageDependencyInspectionFailed(
                status: status,
                output: output
            )
        }
        return try JSONDecoder()
            .decode(SwiftPackageDependencyGraph.self, from: outputData)
            .applyingResolvedRevisions(from: packageDirectory)
    }
}
