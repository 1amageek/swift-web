#if os(macOS)
import AppKit
import SwiftUI

/// Lays a fixture out in an offscreen NSHostingView and returns the probed
/// frames. This is the oracle: whatever SwiftUI produces here is the
/// reference geometry the web rendition is compared against.
@MainActor
enum OracleMeasurement {
    static func measure(_ id: FixtureID) -> [String: ProbeRect] {
        ProbeStore.shared.reset()

        let hosting = NSHostingView(rootView: SwiftUIFixtures.rootView(for: id))
        hosting.frame = NSRect(
            x: 0,
            y: 0,
            width: Harness.rootWidth,
            height: Harness.rootHeight
        )

        let window = NSWindow(
            contentRect: hosting.frame,
            styleMask: [.borderless],
            backing: .buffered,
            defer: false
        )
        window.contentView = hosting
        hosting.layoutSubtreeIfNeeded()
        // GeometryReader bodies run within a display pass; force one so the
        // probes record even without putting the window on screen.
        hosting.display()

        return ProbeStore.shared.snapshot()
    }

    /// Renders the fixture through an offscreen NSHostingView so the report
    /// shows the oracle as an actual rendering. ImageRenderer is not used:
    /// it cannot render scrollable containers (ScrollView content comes out
    /// empty), while a hosted window snapshot draws exactly what SwiftUI
    /// puts on screen, clipping included.
    static func snapshotPNGBase64(_ id: FixtureID) -> String? {
        let hosting = NSHostingView(rootView: SwiftUIFixtures.rootView(for: id))
        hosting.frame = NSRect(
            x: 0,
            y: 0,
            width: Harness.rootWidth,
            height: Harness.rootHeight
        )
        let window = NSWindow(
            contentRect: hosting.frame,
            styleMask: [.borderless],
            backing: .buffered,
            defer: false
        )
        window.contentView = hosting
        hosting.layoutSubtreeIfNeeded()
        guard let bitmap = hosting.bitmapImageRepForCachingDisplay(in: hosting.bounds) else {
            return nil
        }
        hosting.cacheDisplay(in: hosting.bounds, to: bitmap)
        guard let png = bitmap.representation(using: .png, properties: [:]) else {
            return nil
        }
        return png.base64EncodedString()
    }
}
#endif
