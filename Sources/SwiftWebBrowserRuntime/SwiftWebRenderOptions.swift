import SwiftHTML

package enum SwiftWebRenderOptions {
    package static var current: HTMLRenderOptions {
        #if DEBUG
        .development
        #else
        .production
        #endif
    }
}
