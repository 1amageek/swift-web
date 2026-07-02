import SwiftWebDevelopmentHooks
import SwiftWebPackageGeneration
import SwiftWebWasmBuild
import Foundation

package struct SwiftWebDevWorkerTarget: Sendable, Equatable {
    package let host: String
    package let port: Int

    package init(host: String, port: Int) {
        self.host = host
        self.port = port
    }

    package var url: String {
        "http://\(host):\(port)"
    }
}
