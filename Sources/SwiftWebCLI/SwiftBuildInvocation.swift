import Foundation
import SwiftWebDevelopment

struct SwiftBuildInvocation {
    let executableURL: URL
    let argumentsPrefix: [String]

    static func host(
        packageDirectory: URL,
        environment: [String: String] = ProcessInfo.processInfo.environment,
        hostSwiftExecutableURL: URL? = nil
    ) throws -> SwiftBuildInvocation {
        let toolchain = try SwiftWebHostSwiftToolchain.resolve(
            configuration: SwiftWebDevRuntimeConfiguration(
                packageDirectory: packageDirectory,
                hostSwiftExecutableURL: hostSwiftExecutableURL
            ),
            environment: environment
        )
        return SwiftBuildInvocation(
            executableURL: toolchain.swiftExecutableURL,
            argumentsPrefix: []
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
