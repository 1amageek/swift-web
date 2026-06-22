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

struct CatalogRangeControl: Component {
    let label: String
    let value: Binding<Double>

    var body: some HTML {
        div(.class("storyboard-control")) {
            span(.class("storyboard-control-label"), .id(labelID)) {
                label
            }
            // Name the range input from the visible label; a bare range input
            // would otherwise be announced only as "slider".
            Slider(value: value, in: 0...1, step: 0.05, .aria("labelledby", labelID))
                .class("storyboard-control-slider")
            span(.class("storyboard-control-value")) {
                String(format: "%.2f", value.wrappedValue)
            }
        }
    }

    private var labelID: String {
        "storyboard-range-" + String(label.lowercased().map { $0.isLetter || $0.isNumber ? $0 : "-" }) + "-label"
    }
}

struct CatalogStepperControl: Component {
    let label: String
    let value: Binding<Int>

    var body: some HTML {
        div(.class("storyboard-control")) {
            span(.class("storyboard-control-label")) {
                label
            }
            Stepper(label, value: value, in: 0...8)
        }
    }
}

struct CatalogToggleControl: Component {
    let label: String
    let value: Binding<Bool>

    var body: some HTML {
        div(.class("storyboard-control")) {
            span(.class("storyboard-control-label")) {
                label
            }
            Button(value.wrappedValue ? "On" : "Off") {
                value.wrappedValue.toggle()
            }
            .class("storyboard-control-toggle\(value.wrappedValue ? " is-selected" : "")")
        }
    }
}

struct CatalogSegmentControl: Component {
    let label: String
    let selection: Binding<String>
    let options: [CatalogSegmentOption]

    var body: some HTML {
        div(.class("storyboard-control")) {
            span(.class("storyboard-control-label")) {
                label
            }
            HStack(spacing: .xsmall) {
                ForEach(options) { option in
                    Button(option.label) {
                        selection.wrappedValue = option.value
                    }
                    .class("storyboard-control-segment\(selection.wrappedValue == option.value ? " is-selected" : "")")
                }
            }
            .class("storyboard-control-segments")
        }
    }
}

struct CatalogTextControl: Component {
    let label: String
    let value: Binding<String>
    let placeholder: String

    var body: some HTML {
        div(.class("storyboard-control")) {
            span(.class("storyboard-control-label")) {
                label
            }
            TextField(placeholder, text: value)
                .class("storyboard-control-text")
        }
    }
}
