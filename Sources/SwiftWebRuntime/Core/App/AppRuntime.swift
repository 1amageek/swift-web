@_spi(Hosting) import SwiftWebHost

/// Framework-owned state shared while an app is rendered and while its
/// registered handlers serve requests.
package final class AppRuntime: Sendable {
    package let routes: Routes
    package let requestContext: RequestRuntimeContext

    package init(serverConfiguration: ServerConfiguration) {
        self.routes = Routes()
        self.requestContext = RequestRuntimeContext(
            serverConfiguration: serverConfiguration
        )
    }
}
