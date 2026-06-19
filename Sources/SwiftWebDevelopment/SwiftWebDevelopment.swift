@_exported import SwiftWebDevelopmentHooks

public enum SwiftWebDevelopment {
    public static func install() async {
        await SwiftWebDevelopmentHooksRuntime.install()
    }
}
