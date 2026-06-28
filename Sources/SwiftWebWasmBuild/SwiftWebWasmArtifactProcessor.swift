import CryptoKit
import Foundation

public struct SwiftWebWasmArtifactProcessor: Sendable {
    public enum Mode: String, Sendable, Equatable {
        case development
        case production
    }

    public struct Options: Sendable, Equatable {
        public let mode: Mode
        public let runsWasmOptWhenAvailable: Bool
        public let generatesGzipSidecar: Bool
        public let generatesBrotliSidecar: Bool
        public let brotliQuality: Int
        public let writesSizeReport: Bool

        public var inputSignature: String {
            [
                "mode=\(mode.rawValue)",
                "strip=debug-name-producers",
                "wasm-opt=\(runsWasmOptWhenAvailable ? "available" : "disabled")",
                "gzip=\(generatesGzipSidecar ? "enabled" : "disabled")",
                "brotli=\(generatesBrotliSidecar ? "q\(brotliQuality)" : "disabled")",
                "report=\(writesSizeReport ? "enabled" : "disabled")",
            ].joined(separator: ";")
        }

        public static func development(
            environment: [String: String] = ProcessInfo.processInfo.environment
        ) -> Options {
            Options(
                mode: .development,
                runsWasmOptWhenAvailable: wasmOptEnabled(in: environment, defaultValue: false),
                generatesGzipSidecar: false,
                generatesBrotliSidecar: false,
                brotliQuality: 5,
                writesSizeReport: true
            )
        }

        public static func production(
            environment: [String: String] = ProcessInfo.processInfo.environment
        ) -> Options {
            Options(
                mode: .production,
                runsWasmOptWhenAvailable: wasmOptEnabled(in: environment, defaultValue: true),
                generatesGzipSidecar: true,
                generatesBrotliSidecar: true,
                brotliQuality: brotliQuality(in: environment, defaultValue: 11),
                writesSizeReport: true
            )
        }

        private static func wasmOptEnabled(
            in environment: [String: String],
            defaultValue: Bool
        ) -> Bool {
            guard let rawValue = environment["SWIFTWEB_WASM_OPTIMIZE"]?.lowercased() else {
                return defaultValue
            }
            switch rawValue {
            case "1", "true", "yes", "on":
                return true
            case "0", "false", "no", "off":
                return false
            default:
                return defaultValue
            }
        }

        private static func brotliQuality(
            in environment: [String: String],
            defaultValue: Int
        ) -> Int {
            guard let rawValue = environment["SWIFTWEB_WASM_BROTLI_QUALITY"],
                  let quality = Int(rawValue)
            else {
                return defaultValue
            }
            return min(max(quality, 0), 11)
        }
    }

    public struct Result: Sendable, Equatable {
        public let artifactURL: URL
        public let originalBytes: Int
        public let finalBytes: Int
        public let gzipBytes: Int?
        public let brotliBytes: Int?
        public let contentHash: String
        public let transformations: [String]
        public let warnings: [String]
        public let reportURL: URL?
    }

    public enum ProcessingError: Error, CustomStringConvertible {
        case processFailed(command: String, status: Int32)
        case missingOutput(URL)
        case replacementRestoreFailed(target: URL, originalError: String, restoreError: String)

        public var description: String {
            switch self {
            case .processFailed(let command, let status):
                "process failed with status \(status): \(command)"
            case .missingOutput(let url):
                "expected output was not created at \(url.path)"
            case .replacementRestoreFailed(let target, let originalError, let restoreError):
                "failed to restore \(target.path) after replacement failed: \(restoreError); original error: \(originalError)"
            }
        }
    }

    let options: Options
    let environment: [String: String]

    public init(
        options: Options,
        environment: [String: String] = ProcessInfo.processInfo.environment
    ) {
        self.options = options
        self.environment = environment
    }

    public func process(fileURL: URL) throws -> Result {
        var warnings: [String] = []
        var transformations: [String] = []
        let originalData = try Data(contentsOf: fileURL, options: [.mappedIfSafe])
        let originalBytes = originalData.count

        let strippedData = try SwiftWebWasmBinary(data: originalData).strippedData()
        if strippedData != originalData {
            try strippedData.write(to: fileURL, options: [.atomic])
            transformations.append("strip-custom-sections")
        }

        if options.runsWasmOptWhenAvailable {
            if let wasmOptURL = executableURL(named: "wasm-opt") {
                try runWasmOpt(wasmOptURL, fileURL: fileURL)
                transformations.append("wasm-opt -Oz")
            } else {
                warnings.append("wasm-opt was not found; skipped -Oz optimization")
            }
        }

        let finalData = try Data(contentsOf: fileURL, options: [.mappedIfSafe])
        let finalContentHash = Self.contentHash(of: finalData)
        var compressionCache = SwiftWebWasmCompressionCache.load(
            for: fileURL,
            warnings: &warnings
        )
        let gzipBytes = try writeCompressedSidecar(
            toolName: "gzip",
            extensionName: "gz",
            enabled: options.generatesGzipSidecar,
            fileURL: fileURL,
            artifactContentHash: finalContentHash,
            compressionSignature: "gzip -9",
            arguments: { input, _ in
                ["-k", "-f", "-9", input.path]
            },
            compressionCache: &compressionCache,
            warnings: &warnings
        )
        let brotliBytes = try writeCompressedSidecar(
            toolName: "brotli",
            extensionName: "br",
            enabled: options.generatesBrotliSidecar,
            fileURL: fileURL,
            artifactContentHash: finalContentHash,
            compressionSignature: "brotli q\(options.brotliQuality)",
            arguments: { input, output in
                ["-f", "-q", "\(options.brotliQuality)", "-o", output.path, input.path]
            },
            compressionCache: &compressionCache,
            warnings: &warnings
        )
        do {
            try compressionCache.write(for: fileURL)
        } catch {
            warnings.append(
                "WASM compression cache write skipped: \(String(describing: error))"
            )
        }

        let reportURL: URL?
        if options.writesSizeReport {
            let report = try SwiftWebWasmSizeReport(
                artifactURL: fileURL,
                originalBytes: originalBytes,
                finalData: finalData,
                gzipBytes: gzipBytes,
                brotliBytes: brotliBytes,
                transformations: transformations
            )
            try report.write()
            reportURL = report.reportURL
        } else {
            reportURL = nil
        }

        return Result(
            artifactURL: fileURL,
            originalBytes: originalBytes,
            finalBytes: finalData.count,
            gzipBytes: gzipBytes,
            brotliBytes: brotliBytes,
            contentHash: finalContentHash,
            transformations: transformations,
            warnings: warnings,
            reportURL: reportURL
        )
    }

    private func runWasmOpt(_ executableURL: URL, fileURL: URL) throws {
        let outputURL = fileURL
            .deletingLastPathComponent()
            .appendingPathComponent(".swiftweb-\(UUID().uuidString).wasm")
        do {
            try runProcess(
                executableURL: executableURL,
                arguments: ["-Oz", fileURL.path, "-o", outputURL.path],
                currentDirectoryURL: fileURL.deletingLastPathComponent()
            )
            guard FileManager.default.fileExists(atPath: outputURL.path) else {
                throw ProcessingError.missingOutput(outputURL)
            }
            try replaceItem(at: fileURL, with: outputURL)
        } catch {
            if FileManager.default.fileExists(atPath: outputURL.path) {
                do {
                    try FileManager.default.removeItem(at: outputURL)
                } catch let cleanupError {
                    throw cleanupError
                }
            }
            throw error
        }
    }

    private func writeCompressedSidecar(
        toolName: String,
        extensionName: String,
        enabled: Bool,
        fileURL: URL,
        artifactContentHash: String,
        compressionSignature: String,
        arguments: (URL, URL) -> [String],
        compressionCache: inout SwiftWebWasmCompressionCache,
        warnings: inout [String]
    ) throws -> Int? {
        let sidecarURL = URL(fileURLWithPath: fileURL.path + ".\(extensionName)")
        guard enabled else {
            try removeItemIfExists(at: sidecarURL)
            compressionCache.remove(extensionName: extensionName)
            return nil
        }
        if let cachedBytes = try compressionCache.cachedBytes(
            extensionName: extensionName,
            artifactContentHash: artifactContentHash,
            compressionSignature: compressionSignature,
            sidecarURL: sidecarURL
        ) {
            return cachedBytes
        }
        guard let executableURL = executableURL(named: toolName) else {
            try removeItemIfExists(at: sidecarURL)
            compressionCache.remove(extensionName: extensionName)
            warnings.append("\(toolName) was not found; skipped .\(extensionName) sidecar")
            return nil
        }
        try runProcess(
            executableURL: executableURL,
            arguments: arguments(fileURL, sidecarURL),
            currentDirectoryURL: fileURL.deletingLastPathComponent()
        )
        guard FileManager.default.fileExists(atPath: sidecarURL.path) else {
            throw ProcessingError.missingOutput(sidecarURL)
        }
        return try compressionCache.store(
            extensionName: extensionName,
            artifactContentHash: artifactContentHash,
            compressionSignature: compressionSignature,
            sidecarURL: sidecarURL
        )
    }

    private func executableURL(named name: String) -> URL? {
        let searchPath = environment["PATH"] ?? ""
        let directories = searchPath
            .split(separator: ":")
            .map(String.init)
            + ["/opt/homebrew/bin", "/usr/local/bin", "/usr/bin", "/bin"]
        var seen = Set<String>()
        for directory in directories where seen.insert(directory).inserted {
            let candidate = URL(fileURLWithPath: directory)
                .appendingPathComponent(name)
            if FileManager.default.isExecutableFile(atPath: candidate.path) {
                return candidate
            }
        }
        return nil
    }

    private func runProcess(
        executableURL: URL,
        arguments: [String],
        currentDirectoryURL: URL
    ) throws {
        let process = Process()
        process.executableURL = executableURL
        process.arguments = arguments
        process.currentDirectoryURL = currentDirectoryURL
        process.environment = environment
        process.standardInput = FileHandle.standardInput
        process.standardOutput = FileHandle.standardOutput
        process.standardError = FileHandle.standardError

        try process.run()
        process.waitUntilExit()
        guard process.terminationStatus == 0 else {
            throw ProcessingError.processFailed(
                command: ([executableURL.path] + arguments).joined(separator: " "),
                status: process.terminationStatus
            )
        }
    }

    private func replaceItem(at targetURL: URL, with replacementURL: URL) throws {
        guard FileManager.default.fileExists(atPath: targetURL.path) else {
            try FileManager.default.moveItem(at: replacementURL, to: targetURL)
            return
        }

        let backupURL = targetURL
            .deletingLastPathComponent()
            .appendingPathComponent(".swiftweb-\(UUID().uuidString).backup")
        try FileManager.default.moveItem(at: targetURL, to: backupURL)
        do {
            try FileManager.default.moveItem(at: replacementURL, to: targetURL)
        } catch let replacementError {
            do {
                try FileManager.default.moveItem(at: backupURL, to: targetURL)
            } catch let restoreError {
                throw ProcessingError.replacementRestoreFailed(
                    target: targetURL,
                    originalError: String(describing: replacementError),
                    restoreError: String(describing: restoreError)
                )
            }
            throw replacementError
        }
        try FileManager.default.removeItem(at: backupURL)
    }

    private func removeItemIfExists(at url: URL) throws {
        if FileManager.default.fileExists(atPath: url.path) {
            try FileManager.default.removeItem(at: url)
        }
    }

    private static func contentHash(of data: Data) -> String {
        SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined()
    }
}
