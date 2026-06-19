import Foundation
import SwiftHTML
import SwiftWebUI

// MARK: - Detail: Media

struct MediaDetail: Component {
    let selection: String

    var body: some HTML {
        switch selection {
        case "label":
            HStack(spacing: .large) {
                Label("Verified", systemImage: "checkmark.seal.fill")
                Label("Favorite", systemImage: "heart.fill")
                Label("Pinned", systemImage: "pin.fill")
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        default:
            HStack(spacing: .medium) {
                Image(systemName: "star.fill")
                Image(systemName: "bell.badge")
                Image(systemName: "gearshape")
                Image(systemName: "person.crop.circle")
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}

