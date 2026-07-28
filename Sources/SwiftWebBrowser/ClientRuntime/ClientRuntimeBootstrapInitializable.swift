import SwiftHTML

public protocol ClientRuntimeBootstrapInitializable: Component {
    init(bootstrap request: ClientRuntimeBootstrapRequest) throws
}
