import Foundation
import Logging

#if canImport(Darwin)
import Darwin
#endif

public enum SwiftWebDevConsoleLogging {
    public static func bootstrap() {
        guard ProcessInfo.processInfo.environment["SWIFT_WEB_LOG_STYLE"] != "plain" else {
            return
        }

        LoggingSystem.bootstrap({ label, metadataProvider in
            var handler = SwiftWebDevConsoleLogHandler(
                label: label,
                colors: SwiftWebDevConsoleColors.detect()
            )
            handler.metadataProvider = metadataProvider
            return handler
        }, metadataProvider: nil)
    }
}

private struct SwiftWebDevConsoleLogHandler: LogHandler {
    let label: String
    let colors: SwiftWebDevConsoleColors
    var metadataProvider: Logger.MetadataProvider?
    var metadata: Logger.Metadata = [:]
    var logLevel: Logger.Level = .info

    subscript(metadataKey key: String) -> Logger.Metadata.Value? {
        get { metadata[key] }
        set { metadata[key] = newValue }
    }

    func log(event: LogEvent) {
        let mergedMetadata = mergeMetadata(event.metadata)
        let text = event.message.description

        if label == "codes.swiftweb.dev" {
            logSwiftWebDev(level: event.level, message: text, metadata: mergedMetadata)
            return
        }

        logGeneric(level: event.level, message: text, metadata: mergedMetadata)
    }

    private func logSwiftWebDev(
        level: Logger.Level,
        message: String,
        metadata: Logger.Metadata
    ) {
        switch message {
        case let value where value.hasPrefix("SwiftWeb dev server starting"):
            writeHeader(metadata: metadata)
        case "SwiftWeb dev port is already in use":
            writePortInUse(metadata: metadata)
        case "SwiftWeb dev host ready":
            writeStatus("ready", "dev host listening", color: colors.green)
        case "SwiftWeb dev initial client WASM build starting":
            let count = stringValue(metadata["runtimeCount"]) ?? "0"
            writeStatus("build", "client WASM (\(count) runtime\(count == "1" ? "" : "s"))", color: colors.yellow)
        case "SwiftWeb dev initial client WASM build completed":
            let component = stringValue(metadata["component"]) ?? "client"
            writeStatus("ready", "client WASM \(component)", color: colors.green)
        case "SwiftWeb dev child product building and starting":
            writeStatus("build", "server worker", color: colors.yellow)
        case let value where value.hasPrefix("SwiftWeb dev server ready at"):
            let url = stringValue(metadata["url"]) ?? value.replacingOccurrences(of: "SwiftWeb dev server ready at ", with: "")
            writeStatus("ready", colors.cyan(url), color: colors.green)
        case let value where value.hasPrefix("SwiftWeb dev server ready after reload"):
            let url = stringValue(metadata["url"]) ?? value.replacingOccurrences(of: "SwiftWeb dev server ready after reload at ", with: "")
            writeStatus("ready", "reloaded \(colors.cyan(url))", color: colors.green)
        case "SwiftWeb dev change detected":
            writeChange(metadata: metadata)
        case "SwiftWeb dev style HMR event emitted":
            let file = stringValue(metadata["styleFile"]).map { URL(fileURLWithPath: $0).lastPathComponent } ?? "style"
            writeStatus("hmr", "style \(file)", color: colors.cyan)
        case "SwiftWeb dev client component HMR event emitted":
            let component = stringValue(metadata["component"]) ?? "client"
            writeStatus("hmr", "client \(component)", color: colors.cyan)
        case "SwiftWeb dev server rebuild required":
            let reasons = stringValue(metadata["reasons"]) ?? "server change"
            writeStatus("build", "server restart (\(reasons))", color: colors.yellow)
        case "SwiftWeb dev child process exited. Waiting for changes":
            writeStatus("warn", "server worker exited; waiting for changes", color: colors.yellow)
        case "SwiftWeb dev server stopping":
            return
        default:
            logGeneric(level: level, message: message, metadata: metadata)
        }
    }

    private func writeHeader(metadata: Logger.Metadata) {
        let url = stringValue(metadata["url"]) ?? "http://127.0.0.1:3000"
        let packagePath = stringValue(metadata["package"])
        let packageName = packagePath.map { URL(fileURLWithPath: $0).lastPathComponent } ?? "App"
        let watchRootCount = stringValue(metadata["watchRootCount"])
        let watchRootDescription = watchRootCount.map { "\($0) roots" } ?? "enabled"

        write("")
        write("\(colors.bold("sweb")) \(colors.dim("dev"))")
        write("  \(colors.dim("local"))    \(colors.cyan(url))")
        write("  \(colors.dim("package"))  \(packageName)")
        write("  \(colors.dim("watch"))    \(watchRootDescription)")
        write("")
    }

    private func writePortInUse(metadata: Logger.Metadata) {
        let host = stringValue(metadata["host"]) ?? "127.0.0.1"
        let port = stringValue(metadata["port"]) ?? "3000"
        writeStatus("error", "port \(port) is already in use", color: colors.red)
        write("  \(colors.dim("address"))  \(host):\(port)")
        write("  \(colors.dim("try"))      sweb dev --port <available-port>")
    }

    private func writeChange(metadata: Logger.Metadata) {
        let changedPaths = stringValue(metadata["changedPaths"])?
            .split(separator: ",")
            .filter { !$0.isEmpty } ?? []
        let requiresServerRestart = stringValue(metadata["requiresServerRestart"]) == "true"
        let scope = requiresServerRestart ? "server" : "client"
        let count = changedPaths.count
        let fileDescription = count == 1 ? "1 file" : "\(count) files"
        writeStatus("change", "\(fileDescription) -> \(scope)", color: colors.cyan)
    }

    private func logGeneric(
        level: Logger.Level,
        message: String,
        metadata: Logger.Metadata
    ) {
        let normalizedMessage = message.replacingOccurrences(of: "[Vapor] ", with: "")
        if label == "codes.vapor.application",
           ProcessInfo.processInfo.environment["SWIFT_WEB_DEV"] == "1",
           normalizedMessage.hasPrefix("Server started on")
        {
            return
        }

        let levelText = levelName(level)
        let color = levelColor(level)
        var line = "\(color(levelText)) \(normalizedMessage)"

        if let error = stringValue(metadata["error"]) {
            line += " \(colors.dim(error))"
        }

        write(line)
    }

    private func writeStatus(_ status: String, _ message: String, color: (String) -> String) {
        write("\(color(status.padding(toLength: 6, withPad: " ", startingAt: 0))) \(message)")
    }

    private func write(_ line: String) {
        FileHandle.standardError.write(Data((line + "\n").utf8))
    }

    private func mergeMetadata(_ explicitMetadata: Logger.Metadata?) -> Logger.Metadata {
        var values = metadata
        if let providerMetadata = metadataProvider?.get() {
            for (key, value) in providerMetadata {
                values[key] = value
            }
        }
        if let explicitMetadata {
            for (key, value) in explicitMetadata {
                values[key] = value
            }
        }
        return values
    }

    private func stringValue(_ value: Logger.Metadata.Value?) -> String? {
        guard let value else {
            return nil
        }

        switch value {
        case .string(let value):
            return value
        case .stringConvertible(let value):
            return value.description
        case .array(let values):
            return values.compactMap { stringValue($0) }.joined(separator: ",")
        case .dictionary(let values):
            return values.keys.sorted().map { key in
                "\(key)=\(stringValue(values[key]) ?? "")"
            }
            .joined(separator: ",")
        }
    }

    private func levelName(_ level: Logger.Level) -> String {
        switch level {
        case .trace:
            return "trace "
        case .debug:
            return "debug "
        case .info:
            return "info  "
        case .notice:
            return "ready "
        case .warning:
            return "warn  "
        case .error:
            return "error "
        case .critical:
            return "fatal "
        }
    }

    private func levelColor(_ level: Logger.Level) -> (String) -> String {
        switch level {
        case .trace, .debug:
            return colors.dim
        case .info:
            return colors.blue
        case .notice:
            return colors.green
        case .warning:
            return colors.yellow
        case .error, .critical:
            return colors.red
        }
    }
}

private struct SwiftWebDevConsoleColors: Sendable {
    let isEnabled: Bool

    static func detect() -> SwiftWebDevConsoleColors {
        let environment = ProcessInfo.processInfo.environment
        if environment["NO_COLOR"] != nil {
            return SwiftWebDevConsoleColors(isEnabled: false)
        }
        if environment["SWIFT_WEB_FORCE_COLOR"] == "1" {
            return SwiftWebDevConsoleColors(isEnabled: true)
        }
        if environment["TERM"] == "dumb" {
            return SwiftWebDevConsoleColors(isEnabled: false)
        }

        #if canImport(Darwin)
        return SwiftWebDevConsoleColors(isEnabled: isatty(STDERR_FILENO) == 1)
        #else
        return SwiftWebDevConsoleColors(isEnabled: true)
        #endif
    }

    func bold(_ value: String) -> String {
        color("1", value)
    }

    func dim(_ value: String) -> String {
        color("2", value)
    }

    func red(_ value: String) -> String {
        color("31", value)
    }

    func green(_ value: String) -> String {
        color("32", value)
    }

    func yellow(_ value: String) -> String {
        color("33", value)
    }

    func blue(_ value: String) -> String {
        color("34", value)
    }

    func cyan(_ value: String) -> String {
        color("36", value)
    }

    private func color(_ code: String, _ value: String) -> String {
        guard isEnabled else {
            return value
        }
        return "\u{001B}[\(code)m\(value)\u{001B}[0m"
    }
}
