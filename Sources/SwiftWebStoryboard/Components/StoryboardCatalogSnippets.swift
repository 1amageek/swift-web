import Foundation
import SwiftHTML
import SwiftWebUI

func catalogSnippet(for id: String) -> String {
  switch id {
  case "gridsystem":
    return """
      GridSystem(columns: 12, gutter: .medium) {
          Pane(span: 8) { Article() }
          Pane(span: 4) { Sidebar() }
      }
      """
  case "spacing":
    return """
      VStack(spacing: .large) {
          GroupBox { Text("Content") }
              .padding(.medium)
          Button("Continue")
      }
      """
  case "alignment":
    return """
      Text("Hello, SwiftWebUI")
          // centered by default

      Text("Pinned left")
          .frame(maxWidth: .infinity, alignment: .leading)
      """
  case "style":
    return """
      Text("Wi-Fi")

      List {
          HStack {
              Text("Wi-Fi")
              Spacer()
              Text("On", tone: .muted)
          }
      }
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
      Scene {
          Content()
      }

      Hero()
          .ignoresSafeArea()
      """
  case "typography":
    return """
      Text("Hello, SwiftWebUI")
          .font(.largeTitle)
          .fontWeight(.bold)
          .foregroundStyle(.primary)
      """
  case "code":
    return """
      CodeBlock(
          source,
          language: "swift",
          showsLineNumbers: true
      )
      """
  case "colorvalue":
    return """
      Color.blue
          .opacity(1)
          .frame(width: 150, height: 104)
      """
  case "color":
    return """
      HStack(spacing: .small) {
          Button("Accent", prominence: .primary)
              .tint(.accent)
          Button("Danger", prominence: .primary)
              .tint(.danger)
          Button("Custom", prominence: .primary)
              .tint(.css("#22a06b"))
      }
      """
  case "button":
    return """
      HStack(spacing: .small) {
          Button("Primary", prominence: .primary) {
              count += 1
          }
          Button("Secondary") {
              count -= 1
          }
      }
      """
  case "button-styles":
    return """
      HStack(spacing: .small) {
          Button("Glass", prominence: .primary)
              .buttonStyle(.glass)
          Button("Glass prominent", prominence: .primary)
              .buttonStyle(.glassProminent)
          Button("Plain")
              .buttonStyle(.plain)
      }
      """
  case "control-sizes":
    return """
      HStack(spacing: .small) {
          Button("Mini").controlSize(.mini)
          Button("Small").controlSize(.small)
          Button("Regular").controlSize(.regular)
          Button("Large").controlSize(.large)
      }
      """
  case "button-states":
    return """
      HStack(spacing: .small) {
          Button("Enabled", prominence: .primary)
          Button("Disabled", prominence: .primary)
              .disabled()
          SubmitButton("Submit")
              .disabled()
      }
      """
  case "links":
    return """
      HStack(spacing: .small) {
          Link("Documentation", href: "/docs")
              .buttonStyle(.glassProminent)
          Link("Inline anchor", href: "/docs")
      }
      """
  case "textfield":
    return """
      VStack(alignment: .leading, spacing: .small) {
          TextField("Name", text: $name)
          TextField("Email", text: $email, .type(.email), .required)
              .textContentType(.emailAddress)
              .keyboardType(.emailAddress)
              .submitLabel(.go)
      }
      """
  case "securefield":
    return """
      SecureField("Secret", text: $secret)
          .textContentType(.password)
      """
  case "texteditor":
    return """
      TextEditor(text: $notes)
          .frame(minHeight: "120px", alignment: .topLeading)
      """
  case "toggle":
    return """
      Toggle("Enabled", isOn: $enabled)
      """
  case "slider":
    return """
      Slider(value: $volume, in: 0...1, step: 0.05)
      """
  case "stepper":
    return """
      Stepper("Density", value: $density, in: 0...8)
      """
  case "datepicker":
    return """
      VStack(alignment: .leading, spacing: .small) {
          DatePicker("Due date", selection: $due)
          DatePicker(
              "Starts at",
              selection: $due,
              displayedComponents: [.date, .hourAndMinute]
          )
      }
      """
  case "colorpicker":
    return """
      ColorPicker("Accent", selection: $accent)
      """
  case "form":
    return """
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
          }
      }
      """
  case "picker":
    return """
      Picker("View", selection: $segment) {
          PickerOption("List", value: "list")
          PickerOption("Grid", value: "grid")
          PickerOption("Columns", value: "columns")
      }
      .pickerStyle(.segmented)
      """
  case "menu":
    return """
      Menu("Options") {
          Button("Duplicate") {}
          Button("Move...") {}
          Button("Delete") {}
      }
      """
  case "groupbox":
    return """
      GroupBox("Storage") {
          VStack(alignment: .leading, spacing: .small) {
              Text("iCloud Drive")
              Text("128 GB of 200 GB used", tone: .muted)
          }
      }
      """
  case "toolbar":
    return """
      Toolbar {
          Button("Back")
          Spacer()
          Button("Save", prominence: .primary)
      }
      """
  case "badge":
    return """
      HStack(spacing: .small) {
          Badge("Default")
          Badge("Ready")
          Badge("Beta")
      }
      """
  case "list":
    return """
      List {
          ListRow {
              Text("Wi-Fi")
              Spacer()
              Badge("On")
          }
          ListRow {
              Text("Bluetooth")
              Spacer()
              Text("Off", tone: .muted)
          }
      }
      """
  case "section":
    return """
      Section("Account", footer: "Signed in as ada@example.com") {
          VStack(alignment: .leading, spacing: .small) {
              Text("Profile")
              Text("Security")
              Text("Notifications")
          }
      }
      """
  case "disclosuregroup":
    return """
      DisclosureGroup("Advanced options", isExpanded: true) {
          VStack(alignment: .leading, spacing: .small) {
              Text("Nested content reveals when expanded.", tone: .muted)
              Label("Verbose logging", systemImage: "doc.text")
          }
      }
      """
  case "grid":
    return """
      Grid(minColumnWidth: "120px", spacing: .small) {
          Badge("Cell 1")
          Badge("Cell 2")
          Badge("Cell 3")
          Badge("Cell 4")
      }
      """
  case "lazy":
    return """
      Grid(minColumnWidth: "220px", spacing: .large) {
          LazyVStack(alignment: .leading, spacing: .small) {
              Badge("Row 1")
              Badge("Row 2")
          }
          LazyHStack(spacing: .small) {
              Badge("A")
              Badge("B")
          }
          LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: .small) {
              Badge("1")
              Badge("2")
          }
          LazyHGrid(rows: [GridItem(.fixed(28)), GridItem(.fixed(28))], spacing: .small) {
              Badge("1")
              Badge("2")
          }
      }
      """
  case "scrollview":
    return """
      ScrollView(.vertical) {
          LazyVStack(alignment: .leading, spacing: .small) {
              ForEach(items) { item in
                  Badge(item.title)
              }
          }
      }
      .frame(maxWidth: .infinity, height: "160px")
      """
  case "progressview":
    return """
      VStack(alignment: .leading, spacing: .small) {
          ProgressView("Uploading", value: 0.35)
          ProgressView("Rendering", value: 0.7)
          ProgressView("Loading")
      }
      """
  case "gauge":
    return """
      VStack(alignment: .leading, spacing: .small) {
          Gauge(value: 0.25, label: "Disk")
          Gauge(value: 0.62, label: "CPU")
          Gauge(value: 0.9, label: "Memory")
      }
      """
  case "navigationstack":
    return """
      NavigationStack {
          VStack(alignment: .leading, spacing: .small) {
              NavigationLink("Overview", href: "#")
              NavigationLink("Components", href: "#components")
              NavigationLink("Tokens", href: "#tokens")
          }
      }
      """
  case "navigationlink":
    return """
      VStack(alignment: .leading, spacing: .small) {
          NavigationLink("Overview", href: "#overview")
          NavigationLink(href: "#settings") {
              Label("Settings", systemImage: "gear")
          }
      }
      """
  case "tabview":
    return """
      TabView(selection: $tab) {
          Tab("Summary", systemImage: "doc.text", value: "summary") {
              Text("Summary panel content.", tone: .muted)
          }
          Tab("Settings", systemImage: "gear", value: "settings") {
              Text("Settings panel content.", tone: .muted)
          }
      }
      """
  case "searchable":
    return """
      List {
          ListRow { Text("Inbox") }
          ListRow { Text("Drafts") }
          ListRow { Text("Sent") }
      }
      .searchable(text: $query, prompt: "Search folders")
      """
  case "alert":
    return """
      Button("Show alert") {
          showsAlert = true
      }
      .alert("Delete this draft?", isPresented: $showsAlert) {
          Button("Delete", action: Action.post("/delete"))
      } message: {
          Text("This action cannot be undone.")
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
              Text("A sheet lifts a panel to the top layer.", tone: .muted)
              Button("Done") { showsSheet = false }
          }
      }
      """
  case "stacks":
    return """
      Grid(minColumnWidth: "180px", spacing: .large) {
          VStack(alignment: .leading, spacing: .small) {
              Badge("Top")
              Badge("Middle")
              Badge("Bottom")
          }
          HStack(spacing: .small) {
              Badge("A")
              Badge("B")
              Badge("C")
          }
      }
      """
  case "spacer":
    return """
      VStack(alignment: .leading, spacing: .small) {
          HStack(spacing: .small) {
              Badge("leading")
              Spacer()
              Badge("trailing")
          }
          Divider()
      }
      """
  case "divider":
    return """
      VStack(alignment: .leading, spacing: .small) {
          Text("Section one")
          Divider()
          Text("Section two")
      }
      """
  case "hug-fill":
    return """
      VStack(alignment: .leading, spacing: .small) {
          Badge("fixedSize()")
              .fixedSize()
          Badge("frame(maxWidth: .infinity)")
              .frame(maxWidth: .infinity, alignment: .leading)
      }
      """
  case "image":
    return """
      HStack(spacing: .medium) {
          Image(systemName: "star.fill")
          Image(systemName: "bell.badge")
          Image(systemName: "gearshape")
      }
      """
  case "label":
    return """
      HStack(spacing: .large) {
          Label("Verified", systemImage: "checkmark.seal.fill")
          Label("Favorite", systemImage: "heart.fill")
          Label("Pinned", systemImage: "pin.fill")
      }
      """
  default:
    return """
      VStack(alignment: .leading, spacing: .small) {
          Text("Component content")
      }
      """
  }
}
