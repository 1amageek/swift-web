#if canImport(FoundationEssentials)
import FoundationEssentials
#elseif canImport(Foundation)
import Foundation
#endif

package enum SwiftWebRuntime {
    /// Development toggles read from the process environment. Embedded hosts
    /// have no process environment.
    package static var streamsResponses: Bool {
        #if hasFeature(Embedded)
        false
        #else
        ProcessInfo.processInfo.environment["SWIFT_WEB_ENABLE_STREAMING_RESPONSES"] == "1"
        #endif
    }

    package static var hostWebSockets: Bool {
        #if hasFeature(Embedded)
        false
        #else
        true
        #endif
    }
}
