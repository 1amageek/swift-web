/// Shared CSS class tokens for the unified material/glass primitive.
///
/// Every chrome surface composes these tokens instead of hand-rolling its own
/// translucency. The recipe (fill, backdrop blur, specular rim, refraction)
/// lives once in `ThemeStylesheet`; components only pick a level.
enum MaterialClass {
    /// Opaque/translucent surface material (SwiftUI `Material`).
    static let material = "swui-material"
    /// Liquid Glass material (SwiftUI `Glass`).
    static let glass = "swui-glass"

    static let ultraThin = "swui-material-ultra-thin"
    static let thin = "swui-material-thin"
    static let regular = "swui-material-regular"
    static let thick = "swui-material-thick"
    static let ultraThick = "swui-material-ultra-thick"
    static let bar = "swui-material-bar"

    /// Pointer-reactive highlight for interactive glass.
    static let interactive = "swui-glass-interactive"
    /// Shared compositing context for grouped glass surfaces.
    static let container = "swui-glass-container"
}
