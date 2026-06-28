@_exported import SwiftWebDevServer
@_exported import SwiftWebDevelopmentHooks
@_exported import SwiftWebPackageGeneration
@_exported import SwiftWebStoryboardTooling
@_exported import SwiftWebWasmBuild

public enum SwiftWebDevelopment {
    public static func install() async {
        await SwiftWebDevelopmentHooksRuntime.install()
    }
}
