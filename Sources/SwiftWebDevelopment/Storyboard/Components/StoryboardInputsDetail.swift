import Foundation
import SwiftHTML
import SwiftWebUI

// MARK: - Detail: Inputs & controls

struct InputsDetail: Component {
    let selection: String
    /// Shared control-panel state, keyed "componentID.knob".
    let ui: Binding<[String: String]>
    /// The date is kept as a typed binding (the panel only toggles its style).
    let due: Binding<Date>

    private var state: [String: String] { ui.wrappedValue }

    var body: some HTML {
        switch selection {
        case "securefield":
            SecureField("Secret", text: ui.string("securefield.value"))
                .textFieldStyle(fieldStyleKind(state.control("securefield", "fieldStyle")))
        case "texteditor":
            TextEditor(text: ui.string("texteditor.value"), .aria("label", "Notes"))
        case "toggle":
            Toggle(label("toggle", "Enabled"), isOn: ui.bool("toggle.on"))
        case "slider":
            Slider(value: ui.double("slider.value"), in: 0...1, step: 0.05)
                .frame(width: 240)
        case "stepper":
            Stepper("Value", value: ui.int("stepper.value"), in: 0...8)
        case "datepicker":
            datePickerDemo()
        case "colorpicker":
            ColorPicker("Accent", selection: ui.string("colorpicker.value"))
        case "form":
            formDemo()
        default: // textfield
            TextField(placeholder("textfield", "Name"), text: ui.string("textfield.input"), .type(inputType(state.control("textfield", "type"))))
                .textFieldStyle(fieldStyleKind(state.control("textfield", "fieldStyle")))
                .frame(width: 240)
        }
    }

    @HTMLBuilder
    private func datePickerDemo() -> some HTML {
        if state.controlFlag("datepicker", "time") {
            DatePicker("Due date", selection: due, displayedComponents: [.date, .hourAndMinute])
        } else {
            DatePicker("Due date", selection: due, displayedComponents: [.date])
        }
    }

    private func formDemo() -> some HTML {
        Form(action: state.control("form", "action"), method: state.control("form", "method") == "get" ? .get : .post) {
            VStack(alignment: .leading, spacing: .medium) {
                Label("Email address", systemImage: "envelope")
                SubmitButton("Subscribe", prominence: .primary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private func label(_ id: String, _ fallback: String) -> String {
        let value = state.control(id, "label")
        return value.isEmpty ? fallback : value
    }

    private func placeholder(_ id: String, _ fallback: String) -> String {
        let value = state.control(id, "placeholder")
        return value.isEmpty ? fallback : value
    }

    private func inputType(_ value: String) -> InputType {
        switch value {
        case "email": return .email
        case "url": return .url
        default: return .text
        }
    }

    private func fieldStyleKind(_ value: String) -> TextFieldStyleKind {
        switch value {
        case "plain": return .plain
        case "roundedBorder": return .roundedBorder
        default: return .automatic
        }
    }
}
