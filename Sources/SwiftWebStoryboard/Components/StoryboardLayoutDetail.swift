import Foundation
import SwiftHTML
import SwiftWebUI

// MARK: - Detail: Layout

struct LayoutDetail: Component {
    let selection: String

    var body: some HTML {
        switch selection {
        case "spacer":
            HStack(spacing: .small) {
                Badge("leading")
                Spacer()
                Badge("trailing")
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            Divider()
            Text("Above and below are separated by a Divider.", as: .small, tone: .muted)
        case "divider":
            VStack(alignment: .leading, spacing: .small) {
                Text("Section one")
                Divider()
                Text("Section two")
            }
            .class("storyboard-divider-demo")
            .frame(maxWidth: .infinity, alignment: .leading)
        case "hug-fill":
            HStack(spacing: .small) {
                Badge("fixedSize()")
                Text("stays at content width", tone: .muted)
            }
            .padding(.all, "12px 16px")
            .background("color-mix(in srgb, var(--swui-accent) 12%, var(--swui-surface-raised))")
            .cornerRadius("12px")
            .style { .border("1px solid color-mix(in srgb, var(--swui-accent) 32%, transparent)") }
            .fixedSize()

            HStack(spacing: .small) {
                Badge("frame(maxWidth: .infinity)")
                Text("stretches to the full column", tone: .muted)
            }
            .padding(.all, "12px 16px")
            .background("color-mix(in srgb, var(--swui-accent) 12%, var(--swui-surface-raised))")
            .cornerRadius("12px")
            .style { .border("1px solid color-mix(in srgb, var(--swui-accent) 32%, transparent)") }
            .frame(maxWidth: .infinity, alignment: .leading)
        default:
            HStack(spacing: .small) {
                Image(systemName: "checkmark.seal.fill")
                VStack(alignment: .leading, spacing: .xsmall) {
                    Text("Ada Lovelace")
                    Text("Mathematician", tone: .muted)
                }
                Spacer()
                Button("Follow", prominence: .primary)
            }
            .frame(maxWidth: 420, alignment: .leading)
        }
    }
}
