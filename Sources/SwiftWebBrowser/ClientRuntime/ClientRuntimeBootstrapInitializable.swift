import SwiftHTML

public protocol ClientRuntimeBootstrapInitializable: HTML {
    init(bootstrap request: ClientRuntimeBootstrapRequest) throws
}
