import SwiftWebBrowserRuntime
@_spi(Hosting) import SwiftWebHost

private struct ClientRuntimeStorageKey: RuntimeStorageKey {
    typealias Value = SwiftWebClientRuntime
}

extension RequestRuntimeContext {
    package var swiftWebClientRuntime: SwiftWebClientRuntime {
        get {
            storage[ClientRuntimeStorageKey.self] ?? .disabled
        }
        set {
            storage[ClientRuntimeStorageKey.self] = newValue
        }
    }
}

extension Request {
    package var swiftWebClientRuntime: SwiftWebClientRuntime {
        runtimeContext.swiftWebClientRuntime
    }
}
