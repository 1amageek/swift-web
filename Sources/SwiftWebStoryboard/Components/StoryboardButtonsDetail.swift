import Foundation
import SwiftHTML
import SwiftWebUI

// MARK: - Detail: Buttons & actions

struct ButtonsDetail: Component {
    let selection: String

    var body: some HTML {
        switch selection {
        case "button-styles":
            CatalogGlassStage {
                HStack(spacing: .small) {
                    Button("Glass", prominence: .primary)
                        .buttonStyle(.glass)
                    Button("Glass prominent", prominence: .primary)
                        .buttonStyle(.glassProminent)
                    Button("Plain")
                        .buttonStyle(.plain)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        case "control-sizes":
            HStack(spacing: .small) {
                Button("Mini", prominence: .primary)
                    .controlSize(.mini)
                Button("Small", prominence: .primary)
                    .controlSize(.small)
                Button("Regular", prominence: .primary)
                    .controlSize(.regular)
                Button("Large", prominence: .primary)
                    .controlSize(.large)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        case "button-states":
            HStack(spacing: .small) {
                Button("Enabled", prominence: .primary)
                Button("Disabled", prominence: .primary)
                    .disabled()
                SubmitButton("Submit")
                    .disabled()
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        case "links":
            HStack(spacing: .small) {
                ButtonLink("Primary link", href: "#", prominence: .primary)
                ButtonLink("Secondary link", href: "#", prominence: .secondary)
                Link("Anchor", href: "#")
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        default:
            HStack(spacing: .small) {
                Button("Primary", prominence: .primary)
                Button("Secondary")
                Button("Plain")
                    .buttonStyle(.plain)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}

