import Foundation

struct SwiftWebDevServerProcess {
    private let configuration: SwiftWebDevRuntimeConfiguration
    private let devToken: String
    private var process: Process?

    init(configuration: SwiftWebDevRuntimeConfiguration, devToken: String = UUID().uuidString) {
        self.configuration = configuration
        self.devToken = devToken
    }

    var didExit: Bool {
        guard let process else {
            return false
        }
        return !process.isRunning
    }

    mutating func start() throws {
        let executableURL = try buildExecutable()

        let arguments = [
            "--hostname",
            configuration.host,
            "--port",
            String(configuration.port),
        ]

        var environment = try processEnvironment()
        environment["SWIFT_WEB_DEV"] = "1"
        environment["SWIFT_WEB_DEV_RELOAD_TOKEN"] = devToken
        environment[SwiftWebDevEventLog.environmentKey] = SwiftWebDevEventLog
            .fileURL(for: configuration)
            .path
        environment[SwiftWebDevParentProcessMonitor.parentPIDEnvironmentKey] = String(ProcessInfo.processInfo.processIdentifier)

        let process = Process()
        process.executableURL = executableURL
        process.arguments = arguments
        process.currentDirectoryURL = configuration.packageDirectory
        process.environment = environment
        process.standardInput = FileHandle.standardInput
        process.standardOutput = FileHandle.standardOutput
        process.standardError = FileHandle.standardError

        try process.run()
        self.process = process
    }

    mutating func stop() {
        guard let process else {
            return
        }

        if process.isRunning {
            process.terminate()
            process.waitUntilExit()
        }

        self.process = nil
    }

    mutating func clearExitedProcess() -> Int32? {
        guard let process, !process.isRunning else {
            return nil
        }
        let terminationStatus = process.terminationStatus
        self.process = nil
        return terminationStatus
    }

    private func buildExecutable() throws -> URL {
        var buildArguments = swiftBuildArguments()
        buildArguments.append("--product")
        buildArguments.append(configuration.product)
        try runProcess(arguments: buildArguments)

        var binPathArguments = swiftBuildArguments()
        binPathArguments.append("--show-bin-path")
        let binPathOutput = try captureProcessOutput(arguments: binPathArguments)
        guard let binPath = binPathOutput
            .split(whereSeparator: \.isNewline)
            .last
            .map(String.init)?
            .trimmingCharacters(in: .whitespacesAndNewlines),
            !binPath.isEmpty
        else {
            throw SwiftWebDevRuntimeError.executableNotFound(configuration.product)
        }

        let executableURL = URL(fileURLWithPath: binPath).appendingPathComponent(configuration.product)
        guard FileManager.default.isExecutableFile(atPath: executableURL.path) else {
            throw SwiftWebDevRuntimeError.executableNotFound(executableURL.path)
        }

        return executableURL
    }

    private func swiftBuildArguments() -> [String] {
        var arguments = [
            "swift",
            "build",
            "--disable-sandbox",
            "--skip-update",
            "--package-path",
            configuration.packageDirectory.path,
        ]

        if let scratchDirectory = configuration.scratchDirectory {
            arguments.append("--scratch-path")
            arguments.append(scratchDirectory.path)
        }

        return arguments
    }

    private func runProcess(arguments: [String]) throws {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/xcrun")
        process.arguments = arguments
        process.currentDirectoryURL = configuration.packageDirectory
        process.environment = try processEnvironment()
        process.standardInput = FileHandle.standardInput
        process.standardOutput = FileHandle.standardOutput
        process.standardError = FileHandle.standardError

        try process.run()
        process.waitUntilExit()
        guard process.terminationStatus == 0 else {
            throw SwiftWebDevRuntimeError.processFailed(
                command: commandDescription(arguments),
                status: process.terminationStatus
            )
        }
    }

    private func captureProcessOutput(arguments: [String]) throws -> String {
        let process = Process()
        let output = Pipe()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/xcrun")
        process.arguments = arguments
        process.currentDirectoryURL = configuration.packageDirectory
        process.environment = try processEnvironment()
        process.standardInput = FileHandle.standardInput
        process.standardOutput = output
        process.standardError = FileHandle.standardError

        try process.run()
        let data = output.fileHandleForReading.readDataToEndOfFile()
        process.waitUntilExit()
        guard process.terminationStatus == 0 else {
            throw SwiftWebDevRuntimeError.processFailed(
                command: commandDescription(arguments),
                status: process.terminationStatus
            )
        }

        return String(decoding: data, as: UTF8.self)
    }

    private func commandDescription(_ arguments: [String]) -> String {
        (["xcrun"] + arguments).joined(separator: " ")
    }

    private func processEnvironment() throws -> [String: String] {
        let moduleCacheDirectory = self.moduleCacheDirectory
        let temporaryDirectory = self.temporaryDirectory
        try FileManager.default.createDirectory(
            at: moduleCacheDirectory,
            withIntermediateDirectories: true
        )
        try FileManager.default.createDirectory(
            at: temporaryDirectory,
            withIntermediateDirectories: true
        )

        var environment = ProcessInfo.processInfo.environment
        environment["SWIFTPM_MODULECACHE_OVERRIDE"] = moduleCacheDirectory.path
        environment["CLANG_MODULE_CACHE_PATH"] = moduleCacheDirectory.path
        environment["TMPDIR"] = temporaryDirectory.path + "/"
        environment["TMP"] = temporaryDirectory.path
        environment["TEMP"] = temporaryDirectory.path
        return environment
    }

    private var moduleCacheDirectory: URL {
        if let scratchDirectory = configuration.scratchDirectory {
            return scratchDirectory
                .appendingPathComponent("swiftpm-module-cache", isDirectory: true)
                .standardizedFileURL
        }

        return configuration.packageDirectory
            .appendingPathComponent(".swiftweb", isDirectory: true)
            .appendingPathComponent("module-cache", isDirectory: true)
            .standardizedFileURL
    }

    private var temporaryDirectory: URL {
        if let scratchDirectory = configuration.scratchDirectory {
            return scratchDirectory
                .appendingPathComponent("tmp", isDirectory: true)
                .standardizedFileURL
        }

        return configuration.packageDirectory
            .appendingPathComponent(".swiftweb", isDirectory: true)
            .appendingPathComponent("tmp", isDirectory: true)
            .standardizedFileURL
    }
}
