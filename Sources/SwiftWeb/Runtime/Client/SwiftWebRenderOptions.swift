import SwiftHTML

enum SwiftWebRenderOptions {
    static var current: HTMLRenderOptions {
        #if DEBUG
        .development
        #else
        .production
        #endif
    }
}
