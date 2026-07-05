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
                .disabled(state.controlFlag("securefield", "disabled"))
        case "texteditor":
            TextEditor(text: ui.string("texteditor.value"), .aria("label", "Notes"))
                .textFieldStyle(fieldStyleKind(state.control("texteditor", "fieldStyle")))
                .disabled(state.controlFlag("texteditor", "disabled"))
        case "toggle":
            Toggle(label("toggle", "Enabled"), isOn: ui.bool("toggle.on"))
                .toggleStyle(toggleStyleKind(state.control("toggle", "style")))
                .controlSize(controlSize(state.control("toggle", "size")))
                .disabled(state.controlFlag("toggle", "disabled"))
        case "slider":
            sliderDemo()
        case "stepper":
            Stepper("Value", value: ui.int("stepper.value"), in: 0...8)
                .tint(storyboardTintColor(state.control("stepper", "tint")))
                .disabled(state.controlFlag("stepper", "disabled"))
        case "datepicker":
            datePickerDemo()
        case "colorpicker":
            ColorPicker("Accent", selection: ui.string("colorpicker.value"))
                .disabled(state.controlFlag("colorpicker", "disabled"))
        case "form":
            formDemo()
        default: // textfield
            TextField(placeholder("textfield", "Name"), text: ui.string("textfield.input"), .type(inputType(state.control("textfield", "type"))))
                .textFieldStyle(fieldStyleKind(state.control("textfield", "fieldStyle")))
                .controlSize(controlSize(state.control("textfield", "size")))
                .disabled(state.controlFlag("textfield", "disabled"))
                .frame(width: 240)
        }
    }

    @HTMLBuilder
    private func sliderDemo() -> some HTML {
        let stepped = state.controlFlag("slider", "stepped")
        Slider(value: ui.double("slider.value"), in: 0...1, step: stepped ? 0.25 : 0.05)
            .tint(storyboardTintColor(state.control("slider", "tint")))
            .disabled(state.controlFlag("slider", "disabled"))
            .frame(width: 240)
    }

    private func toggleStyleKind(_ value: String) -> ToggleStyleKind {
        switch value {
        case "checkbox": return .checkbox
        default: return .switch
        }
    }

    private func controlSize(_ value: String) -> ControlSize {
        switch value {
        case "small": return .small
        case "large": return .large
        default: return .regular
        }
    }

    @HTMLBuilder
    private func datePickerDemo() -> some HTML {
        let disabled = state.controlFlag("datepicker", "disabled")
        switch state.control("datepicker", "components") {
        case "time":
            DatePicker("Reminder", selection: due, displayedComponents: [.hourAndMinute])
                .disabled(disabled)
        case "date":
            DatePicker("Due date", selection: due, displayedComponents: [.date])
                .disabled(disabled)
        default:
            DatePicker("Event", selection: due, displayedComponents: [.date, .hourAndMinute])
                .disabled(disabled)
        }
    }

    @HTMLBuilder
    private func formDemo() -> some HTML {
        if state.controlFlag("form", "hasAction") {
            Form(action: state.control("form", "action"), method: state.control("form", "method") == "get" ? .get : .post) {
                formFields(submit: true)
            }
        } else {
            Form {
                formFields(submit: false)
            }
        }
    }

    @HTMLBuilder
    private func formFields(submit: Bool) -> some HTML {
        VStack(alignment: .leading, spacing: .medium) {
            Label("Email address", systemImage: "envelope")
            TextField("Email", text: ui.string("form.email"), prompt: Text("you@example.com"))
                .frame(width: 220)
            if submit {
                SubmitButton("Subscribe", prominence: .primary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
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
        case "squareBorder": return .squareBorder
        default: return .automatic
        }
    }
}
