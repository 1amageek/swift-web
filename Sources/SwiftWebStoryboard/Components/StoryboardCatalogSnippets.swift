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
              Text("On").foregroundStyle(.secondary)
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
  case "materials":
    return """
      // Material — frosted vibrancy, for backgrounds
      Panel()
          .background(.regularMaterial, in: .rect(cornerRadius: 18))

      // Liquid Glass — refraction, for floating controls (the default)
      Panel()
          .glassEffect(.regular, in: .rect(cornerRadius: 18))
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
      Code(
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
          Button("Accent").buttonStyle(.borderedProminent)
              .tint(.accent)
          Button("Danger").buttonStyle(.borderedProminent)
              .tint(.danger)
          Button("Custom").buttonStyle(.borderedProminent)
              .tint(Color(hex: 0x22A06B))
      }
      """
  case "button":
    return """
      HStack(spacing: .small) {
          Button("Primary") {
              count += 1
          }
          .buttonStyle(.borderedProminent)
          Button("Secondary") {
              count -= 1
          }
      }
      """
  case "button-styles":
    return """
      HStack(spacing: .small) {
          Button("Glass").buttonStyle(.borderedProminent)
              .buttonStyle(.glass)
          Button("Glass prominent").buttonStyle(.borderedProminent)
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
          Button("Enabled").buttonStyle(.borderedProminent)
          Button("Disabled").buttonStyle(.borderedProminent)
              .disabled()
          SubmitButton("Submit")
              .disabled()
      }
      """
  case "links":
    return """
      HStack(spacing: .small) {
          Link("Documentation", destination: URL(string: "/docs")!)
              .buttonStyle(.glassProminent)
          Link("Inline anchor", destination: URL(string: "/docs")!)
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
          .frame(minHeight: 120, alignment: .topLeading)
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
                  SubmitButton("Subscribe").buttonStyle(.borderedProminent)
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
              Text("128 GB of 200 GB used").foregroundStyle(.secondary)
          }
      }
      """
  case "toolbar":
    return """
      Toolbar {
          Button("Back")
          Spacer()
          Button("Save").buttonStyle(.borderedProminent)
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
              Text("Off").foregroundStyle(.secondary)
          }
      }
      """
  case "section":
    return """
      Section {
          VStack(alignment: .leading, spacing: .small) {
              Text("Profile")
              Text("Security")
              Text("Notifications")
          }
      } header: {
          Heading("Account", level: .subsection)
      } footer: {
          Text("Signed in as ada@example.com").foregroundStyle(.secondary)
      }
      """
  case "disclosuregroup":
    return """
      @State private var advancedOptionsExpanded = true

      DisclosureGroup("Advanced options", isExpanded: $advancedOptionsExpanded) {
          VStack(alignment: .leading, spacing: .small) {
              Text("Nested content reveals when expanded.").foregroundStyle(.secondary)
              Label("Verbose logging", systemImage: "doc.text")
          }
      }
      """
  case "grid":
    return """
      Grid(alignment: .center, horizontalSpacing: 8, verticalSpacing: 8) {
          GridRow {
              Text("Cell 1")
              Text("Cell 2")
          }
          GridRow {
              Text("Cell 3")
              Text("Cell 4")
          }
      }
      """
  case "lazy":
    return """
      Grid(alignment: .leading, horizontalSpacing: 16, verticalSpacing: 16) {
          GridRow {
              LazyVStack(alignment: .leading, spacing: .small) {
                  Text("Row 1")
                  Text("Row 2")
              }
              LazyHStack(spacing: .small) {
                  Text("A")
                  Text("B")
              }
          }
          GridRow {
              LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: .small) {
                  Text("1")
                  Text("2")
              }
              LazyHGrid(rows: [GridItem(.fixed(28)), GridItem(.fixed(28))], spacing: .small) {
                  Text("1")
                  Text("2")
              }
          }
      }
      """
  case "scrollview":
    return """
      ScrollView(.vertical) {
          LazyVStack(alignment: .leading, spacing: .small) {
              ForEach(items) { item in
                  Text(item.title)
              }
          }
      }
      .frame(maxWidth: .infinity, height: 160)
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
              Gauge(value: 0.25) { Text("Disk") }
              Gauge(value: 0.62) { Text("CPU") }
              Gauge(value: 0.9) { Text("Memory") }
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
  case "navigationstack":
    return """
      NavigationStack {
          VStack(alignment: .leading, spacing: .small) {
              NavigationLink("Overview", destination: URL(string: "#")!)
              NavigationLink("Components", destination: URL(string: "#components")!)
              NavigationLink("Tokens", destination: URL(string: "#tokens")!)
          }
      }
      """
  case "navigationlink":
    return """
      VStack(alignment: .leading, spacing: .small) {
          NavigationLink("Overview", destination: URL(string: "#overview")!)
          NavigationLink(destination: URL(string: "#settings")!) {
              Label("Settings", systemImage: "gear")
          }
      }
      """
  case "tabview":
    return """
      TabView(selection: $tab) {
          Tab("Summary", systemImage: "doc.text", value: "summary") {
              Text("Summary panel content.").foregroundStyle(.secondary)
          }
          Tab("Settings", systemImage: "gear", value: "settings") {
              Text("Settings panel content.").foregroundStyle(.secondary)
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
              Text("A sheet lifts a panel to the top layer.").foregroundStyle(.secondary)
              Button("Done") { showsSheet = false }
          }
      }
      """
  case "stacks":
    return """
      HStack(spacing: .small) {
          Image(systemName: "checkmark.seal.fill")
          VStack(alignment: .leading, spacing: .xsmall) {
              Text("Ada Lovelace")
              Text("Mathematician")
                  .foregroundStyle(.secondary)
          }
          Spacer()
          Button("Follow")
              .buttonStyle(.borderedProminent)
      }
      """
  case "spacer":
    return """
      VStack(alignment: .leading, spacing: .small) {
          HStack(spacing: .small) {
              Text("leading")
              Spacer()
              Text("trailing")
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
          Text("fixedSize()")
              .fixedSize()
          Text("frame(maxWidth: .infinity)")
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
