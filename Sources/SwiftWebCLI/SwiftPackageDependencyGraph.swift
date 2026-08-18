import Foundation

struct SwiftPackageDependencyGraph: Decodable, Sendable {
    struct Package: Decodable, Sendable {
        let identity: String
        let name: String
        let url: String
        let version: String
        let path: String
        let dependencies: [Package]

        var directory: URL {
            URL(fileURLWithPath: path, isDirectory: true).standardizedFileURL
        }
    }

    let root: Package

    init(root: Package) {
        self.root = root
    }

    init(from decoder: Decoder) throws {
        root = try Package(from: decoder)
    }
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
        return try JSONDecoder().decode(SwiftPackageDependencyGraph.self, from: outputData)
    }
}
