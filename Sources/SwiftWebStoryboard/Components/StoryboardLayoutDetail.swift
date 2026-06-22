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
            Text("Above and below are separated by a Divider.", as: .small).foregroundStyle(.secondary)
        case "divider":
            VStack(alignment: .leading, spacing: .small) {
                Text("Section one")
                Divider()
                Text("Section two")
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        case "hug-fill":
            HStack(spacing: .small) {
                Badge("fixedSize()")
                Text("stays at content width").foregroundStyle(.secondary)
            }
            .padding(EdgeInsets(top: 12, leading: 16, bottom: 12, trailing: 16))
            .background(Color.accent.opacity(0.12))
            .cornerRadius(12)
            .border(Color.accent.opacity(0.32))
            .fixedSize()

            HStack(spacing: .small) {
                Badge("frame(maxWidth: .infinity)")
                Text("stretches to the full column").foregroundStyle(.secondary)
            }
            .padding(EdgeInsets(top: 12, leading: 16, bottom: 12, trailing: 16))
            .background(Color.accent.opacity(0.12))
            .cornerRadius(12)
            .border(Color.accent.opacity(0.32))
            .frame(maxWidth: .infinity, alignment: .leading)
        default:
            HStack(spacing: .small) {
                Image(systemName: "checkmark.seal.fill")
                VStack(alignment: .leading, spacing: .xsmall) {
                    Text("Ada Lovelace")
                    Text("Mathematician").foregroundStyle(.secondary)
                }
                Spacer()
                Button("Follow").buttonStyle(.borderedProminent)
            }
            .frame(maxWidth: 420, alignment: .leading)
        }
    }
}
