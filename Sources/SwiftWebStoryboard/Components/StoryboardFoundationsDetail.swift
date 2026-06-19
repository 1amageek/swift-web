import Foundation
import SwiftHTML
import SwiftWebUI

// MARK: - Detail: Foundations

struct FoundationsDetail: Component {
    let selection: String

    var body: some HTML {
        switch selection {
        case "gridsystem":
            div(.class("storyboard-grid-demo")) {
                div(.class("storyboard-grid-pane span-8")) {
                    "span 8"
                }
                div(.class("storyboard-grid-pane span-4")) {
                    "span 4"
                }
            }
        case "spacing":
            HStack(spacing: .large) {
                VStack(alignment: .leading, spacing: .xsmall) {
                    spacingBar("4", width: "12px", active: false)
                    spacingBar("8", width: "24px", active: true)
                    spacingBar("16", width: "48px", active: false)
                    spacingBar("24", width: "72px", active: false)
                    spacingBar("32", width: "96px", active: false)
                    spacingBar("40", width: "120px", active: false)
                    spacingBar("48", width: "144px", active: false)
                }
                VStack(spacing: .xsmall) {
                    div(.class("storyboard-spacing-tile")) {
                        ForEach(0..<16, id: \.self) { _ in
                            div {}
                        }
                    }
                    Text("8px grid", as: .small, tone: .muted)
                        .class("storyboard-spacing-grid-label")
                        .monospaced()
                }
            }
            .class("storyboard-spacing-demo")
        case "alignment":
            VStack(spacing: .small) {
                div(.class("storyboard-alignment-frame")) {
                    div(.class("storyboard-alignment-chip")) {
                        "View"
                    }
                }
                Text("default · .center", as: .small, tone: .muted)
                    .monospaced()
            }
            .class("storyboard-centered-demo")
        case "style":
            VStack(spacing: .medium) {
                List {
                    ListRow {
                        Text("Wi-Fi")
                        Spacer()
                        Text("On", tone: .muted)
                    }
                    ListRow {
                        Text("Bluetooth")
                        Spacer()
                        Text("Off", tone: .muted)
                    }
                }
                Text(".swui-list .swui-text { ... }", as: .code)
            }
            .class("storyboard-centered-demo")
        case "responsive":
            VStack(spacing: .small) {
                div(.class("storyboard-responsive-lattice")) {
                    ForEach(0..<12, id: \.self) { _ in
                        div {}
                    }
                }
                div(.class("storyboard-responsive-content")) {
                    div { "span 4" }
                    div { "span 4" }
                    div { "span 4" }
                }
                Text("large · > 1024px · 12 columns", as: .small, tone: .muted)
                    .monospaced()
            }
            .class("storyboard-centered-demo")
        case "safearea":
            VStack(spacing: .small) {
                div(.class("storyboard-phone")) {
                    div(.class("storyboard-phone-notch")) {}
                    div(.class("storyboard-phone-safe-area")) {
                        "safe area"
                    }
                    div(.class("storyboard-phone-home")) {}
                }
                Text("iPhone (notch + home indicator)", as: .small, tone: .muted)
                    .monospaced()
            }
            .class("storyboard-centered-demo")
        case "colorvalue":
            VStack(spacing: .small) {
                div(.class("storyboard-color-swatch")) {}
                Text("Color.blue → #007AFF", as: .small)
                    .monospaced()
            }
            .class("storyboard-centered-demo")
        case "color":
            HStack(spacing: .small) {
                Button("Accent", prominence: .primary)
                    .tint(.accent)
                Button("Danger", prominence: .primary)
                    .tint(.danger)
                Button("Custom", prominence: .primary)
                    .tint(.css("#22a06b"))
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        default:
            Text("Hello, SwiftWebUI")
                .class("storyboard-typography-preview")
                .font(.largeTitle)
                .fontWeight(.bold)
                .foregroundStyle(.primary)
        }
    }

    private func spacingBar(_ label: String, width: String, active: Bool) -> some HTML {
        HStack(spacing: .small) {
            Text(label, as: .small, tone: .muted)
                .class("storyboard-spacing-label")
                .monospaced()
            div(.class("storyboard-spacing-bar\(active ? " is-active" : "")")) {}
                .frame(width: .css(width))
            if active {
                Text("base unit", as: .small)
                    .class("storyboard-spacing-base-label")
            }
        }
    }
}
