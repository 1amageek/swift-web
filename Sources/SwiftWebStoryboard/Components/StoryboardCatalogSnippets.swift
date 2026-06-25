import Foundation
import SwiftHTML
import SwiftWebUI

// MARK: - Snippet helpers

/// Wrap a value in double quotes for inclusion in a Swift source snippet.
private func q(_ value: String) -> String {
    var result = "\""
    for character in value {
        switch character {
        case "\\":
            result += "\\\\"
        case "\"":
            result += "\\\""
        case "\n":
            result += "\\n"
        case "\r":
            result += "\\r"
        case "\t":
            result += "\\t"
        default:
            result.append(character)
        }
    }
    result += "\""
    return result
}

/// Map a tint knob value to its `.role` shape-style expression.
private func tintStyle(_ value: String) -> String { ".\(value)" }

/// Format a 0...1 value with two decimals, matching the design's readouts.
private func f2(_ value: Double) -> String { String(format: "%.2f", value) }

/// Format a value as an integer.
private func iStr(_ value: Double) -> String { String(Int(value)) }

/// Trim a number to its shortest exact decimal (0.6, not 0.60).
private func trimNum(_ value: Double) -> String {
    if value == value.rounded() { return String(Int(value)) }
    return String(format: "%g", value)
}

// MARK: - Usage snippet

/// The Usage code shown for a component. The snippet is generated from the live
/// control-panel `state` so it stays in lock-step with the preview: changing a
/// knob updates the code. Passing an empty `state` yields the registered
/// defaults, so the snippet is meaningful with no interaction.
func catalogSnippet(for id: String, state: [String: String] = [:]) -> String {
  switch id {

  // MARK: Foundations
  case "gridsystem":
    let cols = state.control(id, "cols")
    let gutter = state.control(id, "gutter")
    let preset = state.control(id, "preset")
    let presetsByCols: [String: [String: [Int]]] = [
      "12": ["sidebar": [8, 4], "halves": [6, 6], "thirds": [4, 4, 4], "full": [12]],
      "8": ["sidebar": [5, 3], "halves": [4, 4], "thirds": [3, 3, 2], "full": [8]],
      "4": ["sidebar": [3, 1], "halves": [2, 2], "thirds": [2, 1, 1], "full": [4]],
    ]
    let set = presetsByCols[cols] ?? presetsByCols["12"]!
    let spans = set[preset] ?? set["sidebar"]!
    let panes = spans.enumerated().map { i, s in "    Pane(span: \(s)) { Block\(i + 1)() }" }.joined(separator: "\n")
    let sum = spans.map(String.init).joined(separator: " + ")
    return "// Place content; the grid is applied automatically.\n"
      + "GridSystem(columns: \(cols), gutter: .\(gutter)) {\n"
      + panes + "\n}\n"
      + "// \(sum) = \(cols) · panes stack to full width under 600px"

  case "alignment":
    let align = state.control(id, "align")
    return align == "center"
      ? "Text(\"Hello, SwiftWebUI\")\n    // centered by default — no modifier needed"
      : "Text(\"Hello, SwiftWebUI\")\n    .frame(maxWidth: .infinity, alignment: .\(align))"

  case "hug-fill":
    let align = state.control(id, "align")
    return "VStack(alignment: .leading, spacing: .small) {\n"
      + "    Badge(\"Fixed\")\n"
      + "    Button(\"Flexible\", prominence: .primary)\n"
      + "        .frame(maxWidth: .infinity, alignment: .\(align))\n}"

  // MARK: Content
  case "typography":
    let text = state.control(id, "text")
    let font = state.control(id, "font")
    let weight = state.control(id, "weight")
    let align = state.control(id, "align")
    let fg = state.control(id, "fg")
    let alignLine = align == "center" ? "" : "\n    .multilineTextAlignment(.\(align))"
    return "Text(\(q(text)))\n    .font(.\(font))\n    .fontWeight(.\(weight))\n    .foregroundStyle(.\(fg))" + alignLine

  case "image":
    let name = state.control(id, "name")
    return "Image(systemName: \(q(name)))\n    .foregroundStyle(.accent)"

  case "colorvalue":
    let name = state.control(id, "name")
    let opacity = state.controlNumber(id, "opacity")
    let opLine = opacity < 1 ? "\n    .opacity(\(trimNum(opacity)))" : ""
    return "Color.\(name)" + opLine + "\n    .frame(width: 150, height: 104)"

  case "code":
    let lang = state.control(id, "lang")
    let lineNumbers = state.controlFlag(id, "lineNumbers")
    let lnArg = lineNumbers ? "" : ", showsLineNumbers: false"
    let body = "    \"\"\"\n    struct Counter: View {\n        @State private var count = 0\n    }\n    \"\"\""
    return "Code(language: \(q(lang))\(lnArg)) {\n" + body + "\n}"

  // MARK: Layout & organization
  case "label":
    let title = state.control(id, "title")
    let name = state.control(id, "name")
    return "Label(\(q(title)), systemImage: \(q(name)))"

  case "groupbox":
    let title = state.control(id, "title")
    let pad = state.control(id, "pad")
    let padToken = pad == "compact" ? "small" : pad == "roomy" ? "large" : "medium"
    return "GroupBox(\(q(title))) {\n"
      + "    Text(\"iCloud Drive\")\n"
      + "    Text(\"128 GB of 200 GB used\").foregroundStyle(.secondary)\n}\n"
      + ".padding(.\(padToken))"

  case "list":
    let style = state.control(id, "style")
    return "List {\n"
      + "    ListRow { Text(\"Wi-Fi\"); Spacer(); Badge(\"On\") }\n"
      + "    ListRow { Text(\"Bluetooth\"); Spacer(); Text(\"Off\").foregroundStyle(.secondary) }\n}\n"
      + ".listStyle(.\(style))"

  case "section":
    let title = state.control(id, "title")
    let footer = state.control(id, "footer")
    let footerBlock = footer.isEmpty ? "" : "\n} footer: {\n    Text(\(q(footer))).foregroundStyle(.secondary)"
    return "Section {\n"
      + "    Text(\"Profile\")\n    Text(\"Security\")\n    Text(\"Notifications\")\n"
      + "} header: {\n    Heading(\(q(title)), level: .subsection)"
      + footerBlock + "\n}"

  case "disclosuregroup":
    let open = state.controlFlag(id, "open")
    return "DisclosureGroup(\"Advanced options\", isExpanded: \(open ? "true" : "false")) {\n"
      + "    Label(\"Verbose logging\", systemImage: \"doc.text\")\n}"

  case "grid":
    return "Grid(horizontalSpacing: 12, verticalSpacing: 12) {\n"
      + "    GridRow {\n"
      + "        Image(systemName: \"photo\")\n"
      + "        Image(systemName: \"heart\")\n"
      + "        Image(systemName: \"star\")\n"
      + "    }\n"
      + "    GridRow {\n"
      + "        Text(\"Photos\")\n"
      + "        Text(\"Favorites\")\n"
      + "        Text(\"Featured\")\n"
      + "    }\n"
      + "}"

  case "lazy":
    let axis = state.control(id, "axis")
    let horizontal = axis == "hstack"
    return "ScrollView" + (horizontal ? "(.horizontal)" : "") + " {\n"
      + "    Lazy" + (horizontal ? "HStack" : "VStack") + "(spacing: .small) {\n"
      + "        ForEach(messages) { MessageRow($0) }\n    }\n}"

  case "scrollview":
    let axes = state.control(id, "axes")
    let height = state.controlNumber(id, "height")
    if axes == "horizontal" {
      return "ScrollView(.horizontal) {\n    HStack(spacing: .small) { ForEach(cards) { CardView($0) } }\n}"
    }
    return "ScrollView(.vertical) {\n    VStack(spacing: .medium) { ForEach(paragraphs) { Text($0) } }\n}\n"
      + ".frame(maxWidth: .infinity, height: \"\(iStr(height))px\")"

  case "stacks":
    let axis = state.control(id, "axis")
    if axis == "h" {
      return "HStack(spacing: .small) {\n"
        + "    Image(systemName: \"checkmark.seal.fill\")\n"
        + "    VStack(alignment: .leading) {\n        Text(\"Ada Lovelace\")\n        Text(\"Mathematician\").foregroundStyle(.secondary)\n    }\n"
        + "    Spacer()\n    Button(\"Follow\", prominence: .primary)\n}"
    }
    return "VStack(spacing: .small) {\n"
      + "    Image(systemName: \"checkmark.seal.fill\")\n"
      + "    Text(\"Ada Lovelace\")\n    Text(\"Mathematician\").foregroundStyle(.secondary)\n"
      + "    Button(\"Follow\", prominence: .primary)\n}"

  case "spacer":
    let pos = state.control(id, "pos")
    let inner: String
    switch pos {
    case "leading":
      inner = "    Spacer()\n    Button(\"Back\")\n    Button(\"Save\", prominence: .primary)"
    case "trailing":
      inner = "    Button(\"Back\")\n    Button(\"Save\", prominence: .primary)\n    Spacer()"
    default:
      inner = "    Button(\"Back\")\n    Spacer()\n    Button(\"Save\", prominence: .primary)"
    }
    return "HStack {\n" + inner + "\n}"

  case "divider":
    let orientation = state.control(id, "orientation")
    if orientation == "vertical" {
      return "HStack(spacing: .medium) {\n    Text(\"Edit\")\n    Divider()\n    Text(\"Share\")\n    Divider()\n    Text(\"Delete\")\n}"
    }
    return "VStack(alignment: .leading, spacing: .small) {\n    Text(\"Section one\")\n    Divider()\n    Text(\"Section two\")\n}"

  case "toolbar":
    let label = state.control(id, "label")
    return "Toolbar {\n    Button(\"Back\")\n    Spacer()\n    Button(\(q(label)), prominence: .primary)\n}"

  // MARK: Menus & actions
  case "button":
    let label = state.control(id, "label")
    let prominence = state.control(id, "prominence")
    return "Button(\(q(label)), prominence: .\(prominence)) {\n    count += 1\n}"

  case "button-styles":
    let label = state.control(id, "label")
    let style = state.control(id, "style")
    return "Button(\(q(label))).buttonStyle(.\(style))"

  case "control-sizes":
    let label = state.control(id, "label")
    let size = state.control(id, "size")
    return "Button(\(q(label))).controlSize(.\(size))"

  case "button-states":
    let label = state.control(id, "label")
    let tint = state.control(id, "tint")
    let disabled = state.controlFlag(id, "disabled")
    return "Button(\(q(label)), prominence: .primary)\n    .tint(\(tintStyle(tint)))" + (disabled ? "\n    .disabled()" : "")

  case "links":
    let label = state.control(id, "label")
    let style = state.control(id, "style")
    let tint = state.control(id, "tint")
    let styleLine = style == "plain" ? "" : "\n    .buttonStyle(.\(style))"
    return "Link(\(q(label)), destination: URL(string: \"/docs\")!)" + styleLine + "\n    .tint(\(tintStyle(tint)))"

  case "menu":
    let label = state.control(id, "label")
    let disabled = state.controlFlag(id, "disabled")
    return "Menu(\(q(label))) {\n    Button(\"Duplicate\") {}\n    Button(\"Move…\") {}\n    Button(\"Delete\") {}\n}" + (disabled ? "\n.disabled()" : "")

  // MARK: Navigation & search
  case "navigationstack":
    let title = state.control(id, "title")
    return "NavigationStack {\n    List { … }\n}\n.navigationTitle(\(q(title)))"

  case "navigationlink":
    let label = state.control(id, "label")
    return "NavigationLink(\(q(label)), destination: URL(string: \"#\")!)"

  case "searchable":
    let query = state.control(id, "query")
    let queryComment = query.isEmpty ? "" : "\n// query = \(q(query))"
    return "List { … }\n    .searchable(text: $query, prompt: \"Search folders\")" + queryComment

  // MARK: Presentation
  case "alert":
    let message = state.control(id, "message")
    return "Button(\"Show alert\") { showsAlert = true }\n"
      + ".alert(\"Delete this draft?\", isPresented: $showsAlert) {\n    Button(\"Delete\", action: Action.post(\"/delete\"))\n} message: {\n    Text(\(q(message)))\n}"

  // MARK: Selection & input
  case "textfield":
    let type = state.control(id, "type")
    let fieldStyle = state.control(id, "fieldStyle")
    return "TextField(\"Email\", text: $email, .type(.\(type)))\n    .textFieldStyle(.\(fieldStyle))"

  case "securefield":
    let fieldStyle = state.control(id, "fieldStyle")
    return "SecureField(\"Secret\", text: $secret)\n    .textFieldStyle(.\(fieldStyle))"

  case "toggle":
    let label = state.control(id, "label")
    return "Toggle(\(q(label)), isOn: $isOn)"

  case "slider":
    let value = state.controlNumber(id, "value")
    return "Slider(value: $value, in: 0...1, step: 0.05)\n// value = \(f2(value))"

  case "stepper":
    let value = state.controlNumber(id, "value")
    return "Stepper(\"Density\", value: $density, in: 0...8)\n// value = \(iStr(value))"

  case "picker":
    let value = state.control(id, "value")
    let style = state.control(id, "style")
    return "Picker(\"View\", selection: $segment) {\n"
      + "    PickerOption(\"List\", value: \"list\")\n    PickerOption(\"Grid\", value: \"grid\")\n    PickerOption(\"Columns\", value: \"columns\")\n}\n"
      + ".pickerStyle(.\(style == "menu" ? "menu" : "segmented"))\n// selection = \(q(value))"

  case "datepicker":
    let style = state.control(id, "style")
    let time = state.controlFlag(id, "time")
    let components = time ? "[.date, .hourAndMinute]" : "[.date]"
    return "DatePicker(\n    \"Starts at\",\n    selection: $due,\n    displayedComponents: \(components)\n)\n.datePickerStyle(.\(style))"

  case "colorpicker":
    let value = state.control(id, "value")
    return "ColorPicker(\"Accent\", selection: $accent)\n// \(value)"

  case "color":
    let custom = state.control(id, "custom")
    return "Button(\"Custom\", prominence: .primary)\n    .tint(.css(\(q(custom))))"

  // MARK: Status
  case "progressview":
    let value = state.controlNumber(id, "value")
    let indeterminate = state.controlFlag(id, "indeterminate")
    return indeterminate ? "ProgressView(\"Loading\")" : "ProgressView(\"Uploading\", value: \(f2(value)))"

  case "gauge":
    let value = state.controlNumber(id, "value")
    return "Gauge(value: \(f2(value))) {\n    Text(\"CPU\")\n}"

  case "badge":
    let label = state.control(id, "label")
    let tint = state.control(id, "tint")
    return "Badge(\(q(label)))\n    .tint(\(tintStyle(tint)))"

  case "tabview":
    let tab = state.control(id, "tab")
    return "TabView(selection: $tab) {\n"
      + "    Tab(\"Summary\", systemImage: \"doc.text\", value: \"summary\") { … }\n"
      + "    Tab(\"Settings\", systemImage: \"gear\", value: \"settings\") { … }\n}\n"
      + "// selection = \(q(tab))"

  // MARK: Components whose code does not vary with their controls.
  default:
    return catalogStaticSnippet(for: id)
  }
}

/// Static snippets for components whose Usage code does not change with a knob
/// (the knob varies only the rendered demo, or the component has no knobs).
private func catalogStaticSnippet(for id: String) -> String {
  switch id {
  case "spacing":
    return """
      VStack(spacing: .large) {
          GroupBox { Text("Content") }
              .padding(.medium)
          Button("Continue")
      }
      """
  case "style":
    return """
      let utilityStylesheet = Stylesheet {
          utility(StyleClass("hover:swui-bg-accent"), registry: .swiftWebUI)
          utility(StyleClass("md:swui-fg-secondary"), registry: .swiftWebUI)
      }

      Text("Wi-Fi")
          .class("swui-fg-primary")

      List {
          HStack {
              Text("Wi-Fi")
              Spacer()
              Text("On").foregroundStyle(.secondary)
          }
      }
      .class("swui-bg-surface swui-radius-container hover:swui-bg-accent")
      """
  case "responsive":
    return """
      LazyVGrid(columns: columns, spacing: sizeClass.gutter) {
          ForEach(items) { item in
              ContentTile(item)
          }
      }
      .padding(.horizontal, sizeClass.margin)
      """
  case "safearea":
    return """
      ZStack {
          // Background reaches every edge, behind the notch and home indicator
          Color.accent.ignoresSafeArea()

          // Foreground stays within the safe area
          VStack {
              Text("Title").font(.largeTitle)
              Spacer()
          }
      }
      """
  case "materials":
    return """
      // Material — frosted vibrancy, for backgrounds
      Panel()
          .background(.regularMaterial, in: .rect(cornerRadius: 18))

      // Liquid Glass — refraction, for floating controls (the default)
      Panel()
          .glassEffect(.regular, in: .rect(cornerRadius: 18))
      """
  case "texteditor":
    return """
      TextEditor(text: $notes)
          .frame(minHeight: 120, alignment: .topLeading)
      """
  case "form":
    return """
      Form(action: "/subscribe", method: .post) {
          VStack(alignment: .leading, spacing: .medium) {
              Label("Email address", systemImage: "envelope")
              SubmitButton("Subscribe").buttonStyle(.borderedProminent)
          }
      }
      """
  case "sheet":
    return """
      Button("Show sheet") {
          showsSheet = true
      }
      .sheet(isPresented: $showsSheet) {
          VStack(alignment: .leading, spacing: .medium) {
              Heading("Sheet", level: .section)
              Text("A sheet lifts a panel to the top layer.").foregroundStyle(.secondary)
              Button("Done") { showsSheet = false }
          }
      }
      """
  case "animation":
    return """
      GroupBox {
          Text("Featured")
      }
      .opacity(highlighted ? 1 : 0.3)
      .scaleEffect(highlighted ? 1.08 : 1)
      .animation(.easeInOut(duration: 0.3), value: highlighted)
      """
  case "transition":
    return """
      if isShown {
          GroupBox {
              Text("Now you see me")
          }
          .transition(.scale.combined(with: .opacity))
      }
      """
  case "withanimation":
    return """
      Button {
          withAnimation(.spring(duration: 0.4, bounce: 0.3)) {
              shifted.toggle()
          }
      } label: {
          Text("Animate")
      }

      GroupBox { Text("Springy") }
          .offset(x: shifted ? 64 : 0)
      """
  default:
    return """
      VStack(alignment: .leading, spacing: .small) {
          Text("Component content")
      }
      """
  }
}
