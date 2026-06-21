import Foundation
import SwiftHTML
import SwiftWebUI

// MARK: - Detail: Buttons & actions

struct ButtonsDetail: Component {
    let selection: String

    var body: some HTML {
        switch selection {
        case "button-styles":
            HStack(spacing: .small) {
                Button("Glass").buttonStyle(.borderedProminent)
                    .buttonStyle(.glass)
                Button("Glass prominent").buttonStyle(.borderedProminent)
                    .buttonStyle(.glassProminent)
                Button("Plain")
                    .buttonStyle(.plain)
            }
        case "control-sizes":
            HStack(spacing: .small) {
                Button("Mini").buttonStyle(.borderedProminent)
                    .controlSize(.mini)
                Button("Small").buttonStyle(.borderedProminent)
                    .controlSize(.small)
                Button("Regular").buttonStyle(.borderedProminent)
                    .controlSize(.regular)
                Button("Large").buttonStyle(.borderedProminent)
                    .controlSize(.large)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        case "button-states":
            HStack(spacing: .small) {
                Button("Enabled").buttonStyle(.borderedProminent)
                Button("Disabled").buttonStyle(.borderedProminent)
                    .disabled()
                SubmitButton("Submit")
                    .disabled()
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        case "links":
            HStack(spacing: .small) {
                Link("Documentation", destination: URL(string: "#")!)
                    .buttonStyle(.glassProminent)
                Link("Inline anchor", destination: URL(string: "#")!)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        default:
            HStack(spacing: .small) {
                Button("Primary").buttonStyle(.borderedProminent)
                Button("Secondary")
                Button("Plain")
                    .buttonStyle(.plain)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}
