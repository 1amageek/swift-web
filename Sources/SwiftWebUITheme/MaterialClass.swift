/// Shared CSS class tokens for the unified material/glass primitive.
///
/// Every chrome surface composes these tokens instead of hand-rolling its own
/// translucency. The recipe (fill, backdrop blur, specular rim, refraction)
/// lives once in `RootStylesheet`; components only pick a level.
package enum MaterialClass {
    /// Opaque/translucent surface material (SwiftUI `Material`).
    package static let material = "swui-material"
    /// Liquid Glass material (SwiftUI `Glass`).
    package static let glass = "swui-glass"

    package static let ultraThin = "swui-material-ultra-thin"
    package static let thin = "swui-material-thin"
    package static let regular = "swui-material-regular"
    package static let thick = "swui-material-thick"
    package static let ultraThick = "swui-material-ultra-thick"
    package static let bar = "swui-material-bar"

    /// Pointer-reactive highlight for interactive glass.
    package static let interactive = "swui-glass-interactive"
    /// Shared compositing context for grouped glass surfaces.
    package static let container = "swui-glass-container"
}
