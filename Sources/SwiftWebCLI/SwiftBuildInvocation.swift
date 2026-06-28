import Foundation
import SwiftWebDevelopment

struct SwiftBuildInvocation {
    let executableURL: URL
    let argumentsPrefix: [String]

    static func host(
        environment: [String: String] = ProcessInfo.processInfo.environment,
        fileManager: FileManager = .default
    ) -> SwiftBuildInvocation {
        if let override = environment["SWIFT_WEB_HOST_SWIFT"], !override.isEmpty {
            return SwiftBuildInvocation(
                executableURL: URL(fileURLWithPath: override).standardizedFileURL,
                argumentsPrefix: []
            )
        }
        if fileManager.isExecutableFile(atPath: "/usr/bin/xcrun") {
            return SwiftBuildInvocation(
                executableURL: URL(fileURLWithPath: "/usr/bin/xcrun"),
                argumentsPrefix: ["swift"]
            )
        }
        return SwiftBuildInvocation(
            executableURL: URL(fileURLWithPath: "/usr/bin/env"),
            argumentsPrefix: ["swift"]
        )
    }

    static func wasm(toolchain: SwiftWebWasmToolchain) -> SwiftBuildInvocation {
        SwiftBuildInvocation(
            executableURL: toolchain.swiftExecutableURL,
            argumentsPrefix: []
        )
    }

    func arguments(for swiftArguments: [String]) -> [String] {
        argumentsPrefix + swiftArguments
    }
}
