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

/// Build the `Animation` expression a curve/duration/bounce knob set represents,
/// shared by the animation and withAnimation snippets.
private func animationExpr(_ state: [String: String], _ prefix: String) -> String {
  let curve = state.control(prefix, "curve")
  let duration = String(format: "%.1f", state.controlNumber(prefix, "duration"))
  if curve == "spring" {
    return state.controlFlag(prefix, "bounce")
      ? ".spring(duration: \(duration), bounce: 0.3)"
      : ".spring(duration: \(duration))"
  }
  return ".\(curve)(duration: \(duration))"
}

/// Format a 0...1 value with two decimals, matching the design's readouts.
private func f2(_ value: Double) -> String { String(format: "%.2f", value) }

/// Format a value as an integer.
private func iStr(_ value: Double) -> String { String(Int(value)) }

/// Trim a number to its shortest exact decimal (0.6, not 0.60).
private func trimNum(_ value: Double) -> String {
    if value == value.rounded() { return String(Int(value)) }
    return String(format: "%g", value)
}

private func codeBody(language: String) -> String {
  switch language {
  case "json":
    return "    \"\"\"\n    {\n      \"columns\": 12,\n      \"gutter\": \"medium\"\n    }\n    \"\"\""
  case "bash":
    return "    \"\"\"\n    swift run sweb storyboard --port 3001\n    \"\"\""
  default:
    return "    \"\"\"\n    struct Counter: View {\n        @State private var count = 0\n    }\n    \"\"\""
  }
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
      "12": ["sidebar": [8, 4], "halves": [6, 6], "thirds": [4, 4, 4], "quarters": [3, 3, 3, 3], "wrapping": [6, 6, 12], "full": [12]],
      "8": ["sidebar": [5, 3], "halves": [4, 4], "thirds": [3, 3, 2], "quarters": [2, 2, 2, 2], "wrapping": [4, 4, 8], "full": [8]],
      "4": ["sidebar": [3, 1], "halves": [2, 2], "thirds": [2, 1, 1], "quarters": [1, 1, 1, 1], "wrapping": [2, 2, 4], "full": [4]],
    ]
    let set = presetsByCols[cols] ?? presetsByCols["12"]!
    let spans = set[preset] ?? set["sidebar"]!
    let panes = spans.map { s in "    Pane(span: \(s)) { Text(\"span \(s)\") }" }.joined(separator: "\n")
    let sum = spans.map(String.init).joined(separator: " + ")
    let comment = preset == "wrapping"
      ? "// a span that exceeds the remaining row wraps onto the next"
      : "// \(sum) = \(cols) · panes stack to full width under 600px"
    return "// Place content; the grid is applied automatically.\n"
      + "GridSystem(columns: \(cols), gutter: .\(gutter)) {\n"
      + panes + "\n}\n"
      + comment

  case "spacing":
    let token = state.control(id, "unit")
    return "VStack(spacing: .\(token)) {\n"
      + "    GroupBox { Text(\"Content\") }\n"
      + "        .padding(.\(token))\n"
      + "    Button(\"Continue\")\n"
      + "}"

  case "alignment":
    let align = state.control(id, "align")
    switch state.control(id, "target") {
    case "stack":
      return "VStack(alignment: .\(align), spacing: .xsmall) {\n"
        + "    Text(\"Departures\").fontWeight(.semibold)\n"
        + "    Text(\"Gate 4 · on time\").font(.footnote)\n"
        + "    Text(\"Boarding\").font(.footnote)\n}"
    case "multiline":
      return "Text(\"Wrapped lines align inside the text's own box\")\n"
        + "    .multilineTextAlignment(.\(align))\n"
        + "    .frame(width: 180)"
    default:
      return align == "center"
        ? "Text(\"View\")\n    // centered by default — no modifier needed"
        : "Text(\"View\")\n    .frame(maxWidth: .infinity, alignment: .\(align))"
    }

  case "hug-fill":
    let fill = state.controlFlag(id, "fill")
    let align = state.control(id, "align")
    if state.control(id, "context") == "row" {
      let continueLine = fill
        ? "    Button(\"Continue\").buttonStyle(.borderedProminent)\n        .frame(maxWidth: .infinity, alignment: .\(align))"
        : "    Button(\"Continue\").buttonStyle(.borderedProminent)"
      return "HStack(spacing: .small) {\n    Button(\"Cancel\").buttonStyle(.bordered)\n" + continueLine + "\n}"
    }
    if fill {
      return "Button(\"Flexible\").buttonStyle(.borderedProminent)\n    .frame(maxWidth: .infinity, alignment: .\(align))"
    }
    return "Button(\"Fixed\").buttonStyle(.bordered)\n    // hugs its content by default"

  case "style":
    let context = state.control(id, "ctx")
    switch context {
    case "toolbar":
      return "Text(\"Content\").foregroundStyle(.secondary)\n"
        + "    .toolbar {\n"
        + "        ToolbarItemGroup {\n"
        + "            Text(\"Settings\").fontWeight(.semibold)\n"
        + "            Spacer()\n"
        + "            Button(\"Done\").buttonStyle(.borderedProminent).controlSize(.small)\n"
        + "        }\n"
        + "    }\n"
        + "// the bar exposes .class(\"swui-toolbar\")"
    case "list":
      return "List {\n"
        + "    Text(\"Wi-Fi\").badge(\"On\")\n"
        + "    Text(\"Bluetooth\").badge(\"Off\")\n"
        + "}\n"
        + ".class(\"swui-list\")"
    default:
      return "Text(\"Wi-Fi\")\n"
        + "    .class(\"swui-fg-primary\")"
    }

  case "responsive":
    let bp = state.control(id, "bp")
    switch bp {
    case "compact":
      return "GridSystem(columns: 1, gutter: .small) {\n"
        + "    Pane(span: 1) { Text(\"span 1\") }\n"
        + "    Pane(span: 1) { Text(\"span 1\") }\n"
        + "    Pane(span: 1) { Text(\"span 1\") }\n"
        + "}"
    case "regular":
      return "GridSystem(columns: 8, gutter: .medium) {\n"
        + "    Pane(span: 4) { Text(\"span 4\") }\n"
        + "    Pane(span: 4) { Text(\"span 4\") }\n"
        + "}"
    default:
      return "GridSystem(columns: 12, gutter: .medium) {\n"
        + "    Pane(span: 4) { Text(\"span 4\") }\n"
        + "    Pane(span: 4) { Text(\"span 4\") }\n"
        + "    Pane(span: 4) { Text(\"span 4\") }\n"
        + "}"
    }

  case "materials":
    let level = state.control(id, "level")
    let glass = state.control(id, "glass")
    let tint = state.control(id, "tint")
    let shape = state.control(id, "shape")
    let interactive = state.controlFlag(id, "interactive")
    var glassExpr = ".\(glass)"
    if tint != "none" { glassExpr += ".tint(.\(tint))" }
    if interactive { glassExpr += ".interactive()" }
    let shapeExpr = shape == "capsule" ? ".capsule" : ".rect(cornerRadius: 20)"
    return "HStack(spacing: .large) {\n"
      + "    VStack { Text(\"Material\") }\n"
      + "        .background(.\(level)Material, in: .rect(cornerRadius: 20))\n"
      + "    VStack { Text(\"Liquid Glass\") }\n"
      + "        .glassEffect(\(glassExpr), in: \(shapeExpr))\n"
      + "}"

  // MARK: Content
  case "typography":
    let text = state.control(id, "text")
    let font = state.control(id, "font")
    let weight = state.control(id, "weight")
    let align = state.control(id, "align")
    let fg = state.control(id, "fg")
    let element = state.control(id, "as")
    let asLine = element == "p" ? "" : "\n    .as(.\(element))"
    let alignLine = align == "center" ? "" : "\n    .multilineTextAlignment(.\(align))"
    return "Text(\(q(text)))\(asLine)\n    .font(.\(font))\n    .fontWeight(.\(weight))\n    .foregroundStyle(.\(fg))" + alignLine

  case "image":
    let name = state.control(id, "name")
    let font = state.control(id, "font")
    let fg = state.control(id, "fg")
    return "Image(systemName: \(q(name)))\n    .font(.\(font))\n    .foregroundStyle(.\(fg))"

  case "asyncimage":
    let source = state.control(id, "source")
    let scale = state.control(id, "scale")
    let placeholder = state.controlFlag(id, "placeholder")
    let urlPart = source == "none" ? "url: nil" : (source == "broken" ? "url: URL(string: \"/missing.png\")" : "url: photoURL")
    let scalePart = scale == "1" ? "" : ", scale: \(scale)"
    if placeholder {
      return "AsyncImage(\(urlPart)\(scalePart)) { image in\n    image.clipShape(.rect(cornerRadius: 12))\n} placeholder: {\n    Label(\"Waiting for the image\", systemImage: \"photo\")\n}"
    }
    return "AsyncImage(\(urlPart)\(scalePart))"

  case "colorvalue":
    let name = state.control(id, "name")
    let opacity = state.controlNumber(id, "opacity")
    let opLine = opacity < 1 ? "\n    .opacity(\(trimNum(opacity)))" : ""
    return "Color.\(name)" + opLine + "\n    .frame(width: 150, height: 104)"

  case "code":
    let lang = state.control(id, "lang")
    let lineNumbers = state.controlFlag(id, "lineNumbers")
    let startLine = Int(state.controlNumber(id, "startLine"))
    let startArg = startLine > 1 ? ", startLine: \(startLine)" : ""
    let lnArg = lineNumbers ? "" : ", showsLineNumbers: false"
    let body = codeBody(language: lang)
    return "Code(language: \(q(lang))\(startArg)\(lnArg)) {\n" + body + "\n}"

  // MARK: Layout & organization
  case "label":
    let title = state.control(id, "title")
    let name = state.control(id, "name")
    let font = state.control(id, "font")
    let fg = state.control(id, "fg")
    let fgLine = fg == "primary" ? "" : "\n    .foregroundStyle(.\(fg))"
    return "Label(\(q(title)), systemImage: \(q(name)))\n    .font(.\(font))" + fgLine

  case "groupbox":
    let title = state.control(id, "title")
    let pad = state.control(id, "pad")
    let padToken = pad == "compact" ? "small" : pad == "roomy" ? "large" : "medium"
    let boxContent = "    VStack(alignment: .leading, spacing: .small) {\n"
      + "        Text(\"iCloud Drive\")\n"
      + "        Text(\"128 GB of 200 GB used\").foregroundStyle(.secondary)\n"
      + "    }\n    .padding(.\(padToken))"
    if state.controlFlag(id, "icon") {
      return "GroupBox {\n" + boxContent + "\n} label: {\n    Label(\(q(title)), systemImage: \"doc.text\")\n}"
    }
    return "GroupBox(\(q(title))) {\n" + boxContent + "\n}"

  case "list":
    let style = state.control(id, "style")
    return "List {\n"
      + "    Text(\"Wi-Fi\").badge(\"On\")\n"
      + "    Text(\"Bluetooth\").badge(\"Off\")\n"
      + "    Text(\"Updates\").badge(3)\n}\n"
      + ".listStyle(.\(style))"

  case "section":
    let title = state.control(id, "title")
    let footer = state.control(id, "footer")
    let footerBlock = footer.isEmpty ? "" : "\n} footer: {\n    Text(\(q(footer))).foregroundStyle(.secondary)"
    return "VStack(alignment: .leading, spacing: .medium) {\n"
      + "    Section {\n"
      + "        Text(\"Profile\")\n        Text(\"Security\")\n        Text(\"Notifications\")\n"
      + "    } header: {\n        Text(\(q(title))).as(.h3)"
      + footerBlock.replacingOccurrences(of: "\n", with: "\n    ") + "\n    }\n"
      + "    Section {\n"
      + "        Text(\"iPhone\")\n        Text(\"iPad\")\n"
      + "    } header: {\n        Text(\"Devices\").as(.h3)\n    }\n}"

  case "disclosuregroup":
    let title = state.control(id, "title")
    let open = state.controlFlag(id, "open") ? "true" : "false"
    let dgContent = "    Text(\"Nested content reveals when expanded.\").foregroundStyle(.secondary)\n"
      + "    Label(\"Verbose logging\", systemImage: \"doc.text\")"
    if state.controlFlag(id, "icon") {
      return "DisclosureGroup(isExpanded: \(open)) {\n" + dgContent + "\n} label: {\n    Label(\(q(title)), systemImage: \"bell.badge\")\n}"
    }
    return "DisclosureGroup(\(q(title)), isExpanded: \(open)) {\n" + dgContent + "\n}"

  case "grid":
    let h = Int(state.controlNumber(id, "hSpacing"))
    let v = Int(state.controlNumber(id, "vSpacing"))
    let align = state.control(id, "align")
    let alignArg = align == "center" ? "" : "alignment: .\(align), "
    return "Grid(\(alignArg)horizontalSpacing: \(h), verticalSpacing: \(v)) {\n"
      + "    GridRow {\n        Text(\"Name\").foregroundStyle(.secondary)\n        Text(\"Ada Lovelace\")\n    }\n"
      + "    GridRow {\n        Text(\"Role\").foregroundStyle(.secondary)\n        Text(\"Analyst\")\n    }\n"
      + "    GridRow {\n        Text(\"Team\").foregroundStyle(.secondary)\n        Text(\"Engines\")\n    }\n"
      + "}"

  case "lazy":
    if state.control(id, "kind") == "grid" {
      let adaptive = state.control(id, "tracks") == "adaptive"
      let cols = adaptive
        ? "[GridItem(.adaptive(minimum: 48))]"
        : "[GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible())]"
      return "ScrollView {\n"
        + "    LazyVGrid(columns: \(cols), spacing: .small) {\n"
        + "        ForEach(1...9, id: { i in i }) { i in\n"
        + "            Text(String(format: \"%02d\", i))\n"
        + "        }\n"
        + "    }\n}"
    }
    let axis = state.control(id, "axis")
    let horizontal = axis == "hstack"
    return "ScrollView" + (horizontal ? "(.horizontal)" : "") + " {\n"
      + "    Lazy" + (horizontal ? "HStack" : "VStack") + "(spacing: .small) {\n"
      + "        ForEach([\"Ada\", \"Grace\", \"Alan\", \"Katherine\"], id: { name in name }) { name in\n"
      + "            Text(name)\n"
      + "        }\n"
      + "    }\n}"

  case "scrollview":
    let axes = state.control(id, "axes")
    let height = state.controlNumber(id, "height")
    let indArg = state.controlFlag(id, "showsIndicators") ? "" : ", showsIndicators: false"
    if axes == "horizontal" {
      return "ScrollView(.horizontal\(indArg)) {\n"
        + "    HStack(spacing: .small) {\n"
        + "        ForEach(1...8, id: { index in index }) { index in\n"
        + "            Text(\"Item 0\\(index)\")\n"
        + "                .frame(width: 96)\n"
        + "        }\n"
        + "    }\n}\n"
        + ".frame(maxWidth: .infinity, height: \(iStr(height)))"
    }
    return "ScrollView(.vertical\(indArg)) {\n"
      + "    VStack(alignment: .leading, spacing: .small) {\n"
      + "        ForEach(1...8, id: { index in index }) { index in\n"
      + "            Text(\"Item 0\\(index)\")\n"
      + "        }\n"
      + "    }\n"
      + "    .frame(maxWidth: .infinity, alignment: .leading)\n}\n"
      + ".frame(maxWidth: .infinity, height: \(iStr(height)))"

  case "stacks":
    switch state.control(id, "axis") {
    case "h":
      return "HStack(spacing: .small) {\n"
        + "    Text(\"Leading\")\n    Text(\"Center\")\n    Text(\"Trailing\")\n}"
    case "z":
      return "ZStack {\n"
        + "    Color.blue.opacity(0.18).frame(width: 132, height: 76)\n    Text(\"Overlay\")\n}"
    default:
      return "VStack(spacing: .small) {\n"
        + "    Text(\"Top\")\n    Text(\"Middle\")\n    Text(\"Bottom\")\n}"
    }

  case "spacer":
    let pos = state.control(id, "pos")
    let container = state.control(id, "axis") == "vertical" ? "VStack" : "HStack"
    let inner: String
    switch pos {
    case "leading":
      inner = "    Spacer()\n    Button(\"Back\")\n    Button(\"Save\").buttonStyle(.borderedProminent)"
    case "trailing":
      inner = "    Button(\"Back\")\n    Button(\"Save\").buttonStyle(.borderedProminent)\n    Spacer()"
    case "distributed":
      inner = "    Text(\"A\")\n    Spacer()\n    Text(\"B\")\n    Spacer()\n    Text(\"C\")"
    default:
      inner = "    Button(\"Back\")\n    Spacer()\n    Button(\"Save\").buttonStyle(.borderedProminent)"
    }
    return "\(container) {\n" + inner + "\n}"

  case "divider":
    let orientation = state.control(id, "orientation")
    let constrained = state.controlFlag(id, "constrained")
    let ruleExpr = constrained
      ? (orientation == "vertical" ? "Divider().frame(height: 32)" : "Divider().frame(width: 120)")
      : "Divider()"
    if orientation == "vertical" {
      return "HStack(spacing: .medium) {\n    Text(\"Edit\")\n    \(ruleExpr)\n    Text(\"Share\")\n    \(ruleExpr)\n    Text(\"Delete\")\n}"
    }
    return "VStack(alignment: .leading, spacing: .small) {\n    Text(\"Section one\")\n    \(ruleExpr)\n    Text(\"Section two\")\n}"

  case "toolbar":
    let label = state.control(id, "label")
    let placement = state.control(id, "placement")
    let primary = state.controlFlag(id, "group")
      ? "        ToolbarItemGroup(placement: .\(placement)) {\n            Button(\"Edit\")\n            Button(\(q(label))).buttonStyle(.borderedProminent)\n        }"
      : "        ToolbarItem(placement: .\(placement)) { Button(\(q(label))).buttonStyle(.borderedProminent) }"
    return "Text(\"Content area\")\n"
      + "    .toolbar {\n"
      + "        ToolbarItem(placement: .navigation) { Button(\"Back\") }\n"
      + primary + "\n"
      + "    }"

  // MARK: Menus & actions
  case "button":
    let label = state.control(id, "label")
    let prominence = state.control(id, "prominence")
    let icon = state.controlFlag(id, "icon")
    let labelStyle = state.control(id, "labelStyle")
    let fill = state.controlFlag(id, "fill")
    let styleLine = prominence == "primary" ? "\n    .buttonStyle(.borderedProminent)" : ""
    let fillLine = fill ? "\n    .frame(maxWidth: .infinity)" : ""
    if icon {
      let lsLine = labelStyle == "iconOnly" ? "\n        .labelStyle(.iconOnly)" : ""
      return "Button(action: { count += 1 }) {\n    Label(\(q(label)), systemImage: \"star.fill\")\(lsLine)\n}" + styleLine + fillLine
    }
    return "Button(\(q(label))) {\n    count += 1\n}" + styleLine + fillLine

  case "button-styles":
    let label = state.control(id, "label")
    let style = state.control(id, "style")
    let size = state.control(id, "size")
    let tint = state.control(id, "tint")
    let disabled = state.controlFlag(id, "disabled")
    var out = "Button(\(q(label)))\n    .buttonStyle(.\(style))"
    if size != "regular" { out += "\n    .controlSize(.\(size))" }
    if tint != "accent" { out += "\n    .tint(\(tintStyle(tint)))" }
    if disabled { out += "\n    .disabled()" }
    return out

  case "control-sizes":
    let label = state.control(id, "label")
    let size = state.control(id, "size")
    return "Button(\(q(label))).controlSize(.\(size))"

  case "button-states":
    let label = state.control(id, "label")
    let tint = state.control(id, "tint")
    let disabled = state.controlFlag(id, "disabled")
    return "Button(\(q(label)))\n    .buttonStyle(.borderedProminent)\n    .tint(\(tintStyle(tint)))" + (disabled ? "\n    .disabled()" : "")

  case "links":
    let label = state.control(id, "label")
    let style = state.control(id, "style")
    let tint = state.control(id, "tint")
    let icon = state.controlFlag(id, "icon")
    let disabled = state.controlFlag(id, "disabled")
    let head = icon
      ? "Link(destination: URL(string: \"/docs\")!) {\n    Label(\(q(label)), systemImage: \"envelope\")\n}"
      : "Link(\(q(label)), destination: URL(string: \"/docs\")!)"
    let styleLine = style == "plain" ? "" : "\n    .buttonStyle(.\(style))"
    let tintLine = tint == "accent" ? "" : "\n    .tint(\(tintStyle(tint)))"
    let disabledLine = disabled ? "\n    .disabled()" : ""
    return head + styleLine + tintLine + disabledLine

  case "menu":
    let label = state.control(id, "label")
    let icon = state.controlFlag(id, "icon")
    let disabled = state.controlFlag(id, "disabled")
    let items = "    Button(\"Duplicate\") {}\n    Button(\"Move\") {}\n    Button(\"Delete\") {}"
    let head = icon
      ? "Menu {\n" + items + "\n} label: {\n    Label(\(q(label)), systemImage: \"person.crop.circle\")\n}"
      : "Menu(\(q(label))) {\n" + items + "\n}"
    return head + (disabled ? "\n.disabled()" : "")

  // MARK: Navigation & search
  case "navigationstack":
    let title = state.control(id, "title")
    let rows: String
    if state.controlFlag(id, "icons") {
      rows = "        NavigationLink(destination: URL(string: \"#overview\")!) { Label(\"Overview\", systemImage: \"doc.text\") }\n"
        + "        NavigationLink(destination: URL(string: \"#components\")!) { Label(\"Components\", systemImage: \"photo\") }\n"
        + "        NavigationLink(destination: URL(string: \"#tokens\")!) { Label(\"Tokens\", systemImage: \"chart.bar\") }"
    } else {
      rows = "        NavigationLink(\"Overview\", destination: URL(string: \"#overview\")!)\n"
        + "        NavigationLink(\"Components\", destination: URL(string: \"#components\")!)\n"
        + "        NavigationLink(\"Tokens\", destination: URL(string: \"#tokens\")!)"
    }
    return "NavigationStack {\n"
      + "    VStack(alignment: .leading, spacing: .small) {\n"
      + rows + "\n"
      + "    }\n"
      + "}\n.navigationTitle(\(q(title)))"

  case "navigationlink":
    let label = state.control(id, "label")
    let icon = state.controlFlag(id, "icon")
    let styled = state.control(id, "style") == "bordered"
    let disabled = state.controlFlag(id, "disabled")
    let head = icon
      ? "NavigationLink(destination: URL(string: \"#overview\")!) {\n    Label(\(q(label)), systemImage: \"photo\")\n}"
      : "NavigationLink(\(q(label)), destination: URL(string: \"#overview\")!)"
    let styleLine = styled ? "\n    .buttonStyle(.bordered)" : ""
    let disabledLine = disabled ? "\n    .disabled()" : ""
    return head + styleLine + disabledLine

  case "searchable":
    let query = state.control(id, "query")
    let prompt = state.control(id, "prompt")
    let promptText = prompt.isEmpty ? "Search folders" : prompt
    let queryComment = query.isEmpty ? "" : "\n// query = \(q(query))"
    return "List {\n"
      + "    Text(\"Inbox\")\n"
      + "    Text(\"Drafts\")\n"
      + "    Text(\"Sent\")\n"
      + "}\n.searchable(text: $query, prompt: \(q(promptText)))" + queryComment

  // MARK: Presentation
  case "alert":
    let message = state.control(id, "message")
    return "Button(\"Show alert\") { showsAlert = true }\n"
      + ".alert(\"Delete this draft?\", isPresented: $showsAlert) {\n    Button(\"Delete\", action: Action.post(\"/storyboard/delete\"))\n} message: {\n    Text(\(q(message)))\n}"

  // MARK: Selection & input
  case "textfield":
    let placeholder = state.control(id, "placeholder")
    let type = state.control(id, "type")
    let fieldStyle = state.control(id, "fieldStyle")
    let size = state.control(id, "size")
    let disabled = state.controlFlag(id, "disabled")
    let value = state.control(id, "input")
    var out = "TextField(\(q(placeholder)), text: $text, .type(.\(type)))\n    .textFieldStyle(.\(fieldStyle))"
    if size != "regular" { out += "\n    .controlSize(.\(size))" }
    if disabled { out += "\n    .disabled()" }
    if !value.isEmpty { out += "\n// text = \(q(value))" }
    return out

  case "securefield":
    let fieldStyle = state.control(id, "fieldStyle")
    let disabled = state.controlFlag(id, "disabled")
    return "SecureField(\"Secret\", text: $secret)\n    .textFieldStyle(.\(fieldStyle))" + (disabled ? "\n    .disabled()" : "")

  case "toggle":
    let label = state.control(id, "label")
    let style = state.control(id, "style")
    let size = state.control(id, "size")
    let disabled = state.controlFlag(id, "disabled")
    var out = "Toggle(\(q(label)), isOn: $isOn)"
    if style == "checkbox" { out += "\n    .toggleStyle(.checkbox)" }
    if size != "regular" { out += "\n    .controlSize(.\(size))" }
    if disabled { out += "\n    .disabled()" }
    return out

  case "slider":
    let value = state.controlNumber(id, "value")
    let step = state.controlFlag(id, "stepped") ? "0.25" : "0.05"
    let tint = state.control(id, "tint")
    let disabled = state.controlFlag(id, "disabled")
    var out = "Slider(value: $value, in: 0...1, step: \(step))"
    if tint != "accent" { out += "\n    .tint(\(tintStyle(tint)))" }
    if disabled { out += "\n    .disabled()" }
    out += "\n// value = \(f2(value))"
    return out

  case "stepper":
    let value = state.controlNumber(id, "value")
    let tint = state.control(id, "tint")
    let disabled = state.controlFlag(id, "disabled")
    var out = "Stepper(\"Value\", value: $value, in: 0...8)"
    if tint != "accent" { out += "\n    .tint(\(tintStyle(tint)))" }
    if disabled { out += "\n    .disabled()" }
    out += "\n// value = \(iStr(value))"
    return out

  case "picker":
    let value = state.control(id, "value")
    let style = state.control(id, "style")
    let disabled = state.controlFlag(id, "disabled")
    return "Picker(\"View\", selection: $segment) {\n"
      + "    PickerOption(\"List\", value: \"list\")\n    PickerOption(\"Grid\", value: \"grid\")\n    PickerOption(\"Columns\", value: \"columns\")\n}\n"
      + ".pickerStyle(.\(style))" + (disabled ? "\n.disabled()" : "") + "\n// selection = \(q(value))"

  case "datepicker":
    let components = state.control(id, "components")
    let comps = components == "time" ? "[.hourAndMinute]" : components == "date" ? "[.date]" : "[.date, .hourAndMinute]"
    let disabled = state.controlFlag(id, "disabled")
    return "DatePicker(\n    \"Event\",\n    selection: $due,\n    displayedComponents: \(comps)\n)" + (disabled ? "\n.disabled()" : "")

  case "colorpicker":
    let value = state.control(id, "value")
    let disabled = state.controlFlag(id, "disabled")
    return "ColorPicker(\"Accent\", selection: $accent)" + (disabled ? "\n    .disabled()" : "") + "\n// \(value)"

  case "color":
    let name = state.control(id, "name")
    let opacity = state.controlNumber(id, "opacity")
    let custom = state.control(id, "custom")
    let opLine = opacity < 1 ? ".opacity(\(trimNum(opacity)))" : ""
    return "let tint = Color.\(name)\(opLine)\n"
      + "let custom = Color.css(\(q(custom)))\n"
      + "// palette colors adapt via light-dark(); .css is an exact value"

  // MARK: Status
  case "progressview":
    let value = state.controlNumber(id, "value")
    let indeterminate = state.controlFlag(id, "indeterminate")
    let hasLabel = state.controlFlag(id, "label")
    if indeterminate {
      return hasLabel ? "ProgressView(\"Loading\")" : "ProgressView()"
    }
    return hasLabel ? "ProgressView(\"Progress\", value: \(f2(value)))" : "ProgressView(value: \(f2(value)))"

  case "gauge":
    let value = state.controlNumber(id, "value")
    let tint = state.control(id, "tint")
    let tintLine = tint == "accent" ? "" : "\n    .tint(\(tintStyle(tint)))"
    return "Gauge(value: \(f2(value))) {\n    Text(\"Value\")\n}" + tintLine

  case "badge":
    let label = state.control(id, "label")
    let tint = state.control(id, "tint")
    let badgeArg = state.control(id, "kind") == "count" ? "\(Int(label) ?? 3)" : q(label)
    return "Text(\"Wi-Fi\")\n    .badge(\(badgeArg))\n    .tint(\(tintStyle(tint)))"

  case "tabview":
    let tab = state.control(id, "tab")
    let icons = state.controlFlag(id, "icons")
    let img: (String) -> String = { symbol in icons ? ", systemImage: \(q(symbol))" : "" }
    return "TabView(selection: $tab) {\n"
      + "    Tab(\"Summary\"\(img("doc.text")), value: \"summary\") { Text(\"Summary panel content.\") }\n"
      + "    Tab(\"Activity\"\(img("chart.bar")), value: \"activity\") { Text(\"Activity panel content.\") }\n"
      + "    Tab(\"Settings\"\(img("gear")), value: \"settings\") { Text(\"Settings panel content.\") }\n}\n"
      + "// selection = \(q(tab))"

  // MARK: Components whose code does not vary with their controls.
  default:
    return catalogStaticSnippet(for: id, state: state)
  }
}

/// Static snippets for components whose Usage code does not change with a knob
/// (the knob varies only the rendered demo, or the component has no knobs).
private func catalogStaticSnippet(for id: String, state: [String: String]) -> String {
  switch id {
  case "safearea":
    let ignore = state.control(id, "ignore")
    let background = ignore == "all"
      ? "Color.accent.ignoresSafeArea()"
      : ignore == "top" ? "Color.accent.ignoresSafeArea(edges: .top)" : "Color.accent"
    return """
      ZStack {
          // Background; ignoresSafeArea lets it reach under the chrome
          \(background)

          // Foreground stays within the safe area
          VStack {
              Text("Title").font(.largeTitle)
              Spacer()
          }
      }
      """
  case "texteditor":
    let value = state.control(id, "value")
    let fieldStyle = state.control(id, "fieldStyle")
    let disabled = state.controlFlag(id, "disabled")
    var out = "TextEditor(text: $notes)\n    .frame(minHeight: 120, alignment: .topLeading)"
    if fieldStyle == "plain" { out += "\n    .textFieldStyle(.plain)" }
    if disabled { out += "\n    .disabled()" }
    out += "\n\n// text = \(q(value))"
    return out
  case "form":
    let method = state.control(id, "method")
    let action = state.control(id, "action")
    if state.controlFlag(id, "hasAction") {
      return """
        Form(action: \(q(action)), method: .\(method)) {
            VStack(alignment: .leading, spacing: .medium) {
                Label("Email address", systemImage: "envelope")
                TextField("Email", text: $email)
                SubmitButton("Subscribe", prominence: .primary)
            }
        }
        """
    }
    return """
      // No action lowers to a <div>, so Enter cannot submit implicitly.
      Form {
          VStack(alignment: .leading, spacing: .medium) {
              Label("Email address", systemImage: "envelope")
              TextField("Email", text: $email)
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
              Text("Sheet").as(.h2)
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
      .animation(\(animationExpr(state, id)), value: highlighted)
      """
  case "transition":
    let isShown = state.controlFlag(id, "on")
    let transitionExpr: String
    switch state.control(id, "kind") {
    case "opacity": transitionExpr = ".opacity"
    case "move": transitionExpr = ".move(edge: .bottom)"
    case "slide": transitionExpr = ".slide"
    case "asymmetric": transitionExpr = ".asymmetric(insertion: .move(edge: .leading), removal: .opacity)"
    default: transitionExpr = ".scale.combined(with: .opacity)"
    }
    return """
      if isShown {
          GroupBox {
              Text("Now you see me")
          }
          .transition(\(transitionExpr))
      }

      // isShown = \(isShown ? "true" : "false")
      """
  case "withanimation":
    return """
      Button {
          withAnimation(\(animationExpr(state, id))) {
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
