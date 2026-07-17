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

    /// Renders the fixture with SwiftUI's own ImageRenderer so the report
    /// can show the oracle as an actual rendering, not just outlines.
    static func snapshotPNGBase64(_ id: FixtureID) -> String? {
        let renderer = ImageRenderer(content: SwiftUIFixtures.rootView(for: id))
        renderer.proposedSize = ProposedViewSize(
            width: Harness.rootWidth,
            height: Harness.rootHeight
        )
        renderer.scale = 2
        guard
            let nsImage = renderer.nsImage,
            let tiff = nsImage.tiffRepresentation,
            let bitmap = NSBitmapImageRep(data: tiff),
            let png = bitmap.representation(using: .png, properties: [:])
        else {
            return nil
        }
        return png.base64EncodedString()
    }
}
#endif
