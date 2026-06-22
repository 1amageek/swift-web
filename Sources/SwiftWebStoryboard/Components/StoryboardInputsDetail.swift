import Foundation
import SwiftHTML
import SwiftWebUI

// MARK: - Detail: Inputs & controls

struct InputsDetail: Component {
  let selection: String
  let name: Binding<String>
  let email: Binding<String>
  let secret: Binding<String>
  let notes: Binding<String>
  let enabled: Binding<Bool>
  let volume: Binding<Double>
  let density: Binding<Int>
  let due: Binding<Date>
  let accent: Binding<String>

  var body: some HTML {
    switch selection {
    case "securefield":
      SecureField("Secret", text: secret)
    case "texteditor":
      TextEditor(text: notes, .aria("label", "Notes"))
    case "toggle":
      Toggle("Enabled", isOn: enabled)
    case "slider":
      Slider(value: volume, in: 0...1, step: 0.05)
    case "stepper":
      Stepper("Density", value: density, in: 0...8)
    case "datepicker":
      DatePicker("Due date", selection: due)
      DatePicker(
        "Starts at",
        selection: due,
        displayedComponents: [.date, .hourAndMinute]
      )
    case "colorpicker":
      ColorPicker("Accent", selection: accent)
    case "form":
      Form(action: "/subscribe", method: .post) {
        VStack(alignment: .leading, spacing: .medium) {
          Label("Email address", systemImage: "envelope")
          HStack(spacing: .small) {
            SubmitButton("Subscribe", prominence: .primary)
              .name("intent")
              .value("subscribe")
            SubmitButton("Unsubscribe")
              .name("intent")
              .value("unsubscribe")
          }
          .frame(maxWidth: .infinity, alignment: .leading)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
      }
    default:
      TextField("Name", text: name)
      TextField("Email", text: email, .type(.email), .required)
        .textContentType(.emailAddress)
        .keyboardType(.emailAddress)
        .submitLabel(.go)
    }
  }
}
