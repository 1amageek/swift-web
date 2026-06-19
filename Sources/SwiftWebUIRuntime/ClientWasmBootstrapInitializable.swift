import SwiftHTML

public protocol ClientWasmBootstrapInitializable: HTML {
    init(bootstrap request: ClientWasmBootstrapRequest) throws
}
