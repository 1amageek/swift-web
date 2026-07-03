import Foundation
import SwiftHTML
import SwiftWebUI

// MARK: - Detail: Media

/// A self-contained sample photo (SVG data URL), so the catalog needs no
/// network to demonstrate a successful load.
let storyboardSampleImageURL = URL(
    string: "data:image/svg+xml;base64,PHN2ZyB4bWxucz0naHR0cDovL3d3dy53My5vcmcvMjAwMC9zdmcnIHdpZHRoPScyNDAnIGhlaWdodD0nMTUwJz48ZGVmcz48bGluZWFyR3JhZGllbnQgaWQ9J2cnIHgxPScwJyB5MT0nMCcgeDI9JzEnIHkyPScxJz48c3RvcCBvZmZzZXQ9JzAnIHN0b3AtY29sb3I9JyM4ZWM1ZmMnLz48c3RvcCBvZmZzZXQ9JzEnIHN0b3AtY29sb3I9JyNlMGMzZmMnLz48L2xpbmVhckdyYWRpZW50PjwvZGVmcz48cmVjdCB3aWR0aD0nMjQwJyBoZWlnaHQ9JzE1MCcgZmlsbD0ndXJsKCNnKScvPjxjaXJjbGUgY3g9JzE3OCcgY3k9JzQ0JyByPScyMCcgZmlsbD0nI2ZmZicgb3BhY2l0eT0nMC44NScvPjxwYXRoIGQ9J00wIDExOCBMNjAgNzAgTDExMCAxMDggTDE2MCA2MiBMMjQwIDEyMiBMMjQwIDE1MCBMMCAxNTAgWicgZmlsbD0nIzViN2RiMScgb3BhY2l0eT0nMC43NScvPjwvc3ZnPg=="
)!

/// A path that never resolves, demonstrating that a failed load keeps the
/// placeholder visible.
let storyboardBrokenImageURL = URL(string: "/storyboard/assets/missing.png")!

struct MediaDetail: Component {
    let selection: String
    /// Shared control-panel state, keyed "componentID.knob".
    var state: [String: String] = [:]

    var body: some HTML {
        switch selection {
        case "label":
            let title = state.control("label", "title")
            Label(title.isEmpty ? "Verified" : title, systemImage: state.control("label", "name"))
                .font(.title2)
        case "asyncimage":
            let source = state.control("asyncimage", "source")
            let url: URL? =
                source == "none"
                ? nil
                : (source == "broken" ? storyboardBrokenImageURL : storyboardSampleImageURL)
            AsyncImage(url: url) { image in
                image.clipShape(.rect(cornerRadius: 12))
            } placeholder: {
                Label("Waiting for the image", systemImage: "photo")
                    .foregroundStyle(.secondary)
                    .frame(width: 240, height: 150)
                    .background(.surfaceRaised, in: .rect(cornerRadius: 12))
            }
        default: // image
            Image(systemName: state.control("image", "name"))
                .font(.largeTitle)
                .foregroundStyle(.accent)
        }
    }
}
