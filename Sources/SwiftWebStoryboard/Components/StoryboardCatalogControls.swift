import Foundation
import SwiftHTML
import SwiftWebUI

struct CatalogSegmentOption: Identifiable, Sendable {
    let id: String
    let label: String
    let value: String

    init(label: String, value: String) {
        self.id = value
        self.label = label
        self.value = value
    }
}

private func controlLabel(_ label: String) -> some HTML {
    Text(label, as: .span)
        .font(.footnote)
        .fontWeight(.medium)
        .foregroundStyle(.secondary)
}

struct CatalogRangeControl: Component {
    let label: String
    let value: Binding<Double>

    var body: some HTML {
        HStack(spacing: .medium) {
            // Name the range input from the visible label; a bare range input
            // would otherwise be announced only as "slider".
            Text(label, as: .span, .id(labelID))
                .font(.footnote)
                .fontWeight(.medium)
                .foregroundStyle(.secondary)
            Slider(value: value, in: 0...1, step: 0.05, .aria("labelledby", labelID))
                .frame(maxWidth: .infinity)
            Text(String(format: "%.2f", value.wrappedValue))
                .font(Font(size: .px(13), design: .monospaced))
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var labelID: String {
        "storyboard-range-" + String(label.lowercased().map { $0.isLetter || $0.isNumber ? $0 : "-" }) + "-label"
    }
}

struct CatalogStepperControl: Component {
    let label: String
    let value: Binding<Int>

    var body: some HTML {
        HStack(spacing: .medium) {
            controlLabel(label)
            Stepper(label, value: value, in: 0...8)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

struct CatalogToggleControl: Component {
    let label: String
    let value: Binding<Bool>

    var body: some HTML {
        Toggle(label, isOn: value)
            .frame(maxWidth: .infinity, alignment: .leading)
    }
}

struct CatalogSegmentControl: Component {
    let label: String
    let selection: Binding<String>
    let options: [CatalogSegmentOption]

    var body: some HTML {
        HStack(spacing: .medium) {
            controlLabel(label)
            HStack(spacing: .xsmall) {
                ForEach(options) { option in
                    Button(action: { selection.wrappedValue = option.value }) {
                        Text(option.label)
                    }
                    .buttonStyle(.plain)
                    .font(Font(size: .px(13), weight: .medium))
                    .foregroundStyle(.primary)
                    .padding(.horizontal, 11)
                    .frame(height: 28)
                    .background(
                        Color.surfaceRaised.opacity(selection.wrappedValue == option.value ? 1 : 0),
                        in: .rect(cornerRadius: 6)
                    )
                }
            }
            .padding(3)
            // Filled track only — no hard outline (matches a native segmented control).
            .background(Color.secondary.opacity(0.1), in: .rect(cornerRadius: 8))
            .cornerRadius(8)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

struct CatalogTextControl: Component {
    let label: String
    let value: Binding<String>
    let placeholder: String

    var body: some HTML {
        HStack(spacing: .medium) {
            controlLabel(label)
            TextField(placeholder, text: value)
                .frame(maxWidth: .infinity)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}
