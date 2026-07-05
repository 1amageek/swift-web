import Foundation
import SwiftHTML
import SwiftWebUI

// MARK: - Detail: Foundations

struct FoundationsDetail: Component {
    let selection: String
    /// Shared control-panel state, keyed "componentID.knob".
    var state: [String: String] = [:]

    var body: some HTML {
        switch selection {
        case "gridsystem":
            // Reactive: columns, gutter, and arrangement are driven by the panel.
            let cols = Int(state.control("gridsystem", "cols")) ?? 12
            let spans = gridPanes(state.control("gridsystem", "preset"), cols)
            GridSystem(columns: cols, gutter: gridGutter(state.control("gridsystem", "gutter"))) {
                ForEach(spans.indices, id: { index in index }) { index in
                    Pane(span: spans[index]) { gridPane("span \(spans[index])") }
                }
            }
            .frame(maxWidth: .infinity)
        case "spacing":
            let token = state.control("spacing", "unit")
            HStack(alignment: .top, spacing: .large) {
                VStack(alignment: .leading, spacing: .xsmall) {
                    spacingBar(".xsmall", width: 32, active: token == "xsmall")
                    spacingBar(".small", width: 48, active: token == "small")
                    spacingBar(".medium", width: 72, active: token == "medium")
                    spacingBar(".large", width: 96, active: token == "large")
                }
                VStack(spacing: spacingSpace(token)) {
                    GroupBox("Content") {
                        Text("Spacing token")
                            .foregroundStyle(.secondary)
                    }
                    Button("Continue").buttonStyle(.borderedProminent)
                    Text(".\(token)").as(.small)
                        .font(Font(size: .px(12), design: .monospaced))
                        .foregroundStyle(.secondary)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        case "alignment":
            // The `target` control selects which alignment concept the demo
            // exercises: positioning inside a frame, a stack's cross-axis
            // alignment, or wrapped-line alignment inside the text's own box.
            alignmentDemo(align: state.control("alignment", "align"), target: state.control("alignment", "target"))
        case "style":
            // The same Text renders differently by context: bare, inside a List
            // row, or inside a toolbar attached through the toolbar modifier.
            // The selected context drives both the demo and the CSS note
            // beneath it.
            styleDemo(state.control("style", "ctx"))
        case "responsive":
            // The size-class control (key "bp") drives column count, span, and
            // gutter, so the same lattice reflows by breakpoint instead of scaling.
            let bp = state.control("responsive", "bp")
            VStack(spacing: .small) {
                switch bp {
                case "compact":
                    GridSystem(columns: 1, gutter: .small) {
                        Pane(span: 1) { gridPane("span 1") }
                        Pane(span: 1) { gridPane("span 1") }
                        Pane(span: 1) { gridPane("span 1") }
                    }
                    .frame(maxWidth: .infinity)
                case "regular":
                    GridSystem(columns: 8, gutter: .medium) {
                        Pane(span: 4) { gridPane("span 4") }
                        Pane(span: 4) { gridPane("span 4") }
                    }
                    .frame(maxWidth: .infinity)
                default:
                    GridSystem(columns: 12, gutter: .medium) {
                        Pane(span: 4) { gridPane("span 4") }
                        Pane(span: 4) { gridPane("span 4") }
                        Pane(span: 4) { gridPane("span 4") }
                    }
                    .frame(maxWidth: .infinity)
                }
                Text(responsiveCaption(bp)).as(.small)
                    .font(Font(size: .px(12), design: .monospaced))
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity)
        case "safearea":
            // The device context changes how much chrome (notch + home indicator,
            // a browser toolbar, or none) insets the safe area; the ignore control
            // extends an accent background under that chrome, edge to edge.
            let device = state.control("safearea", "device")
            let ignore = state.control("safearea", "ignore")
            VStack(spacing: .small) {
                deviceMock(device, ignore: ignore)
                Text("\(safeAreaLabel(device)) · \(ignoreLabel(ignore))").as(.small)
                    .font(Font(size: .px(12), design: .monospaced))
                    .foregroundStyle(.secondary)
            }
        case "colorvalue":
            let name = state.control("colorvalue", "name")
            let opacity = state.controlNumber("colorvalue", "opacity")
            VStack(spacing: .small) {
                VStack {}
                    .frame(width: 150, height: 88)
                    .background(Color(cssValue: paletteHex(name)).opacity(opacity), in: .rect(cornerRadius: 12))
                Text("Color.\(name) · opacity \(String(format: "%.2f", opacity))").as(.small)
                    .font(Font(size: .px(12), design: .monospaced))
                    .foregroundStyle(.secondary)
            }
        case "color":
            colorDemo()
        case "typography":
            let text = state.control("typography", "text")
            Text(text.isEmpty ? "Hello, SwiftWebUI" : text)
                .as(typographyElement(state.control("typography", "as")))
                .font(typographyFont(state.control("typography", "font")))
                .fontWeight(typographyWeight(state.control("typography", "weight")))
                .multilineTextAlignment(typographyTextAlignment(state.control("typography", "align")))
                .foregroundStyle(typographyForeground(state.control("typography", "fg")))
                .frame(maxWidth: .infinity, alignment: typographyAlignment(state.control("typography", "align")))
        case "materials":
            // A soft gradient with faint typography behind, so the two effects are
            // evaluable side by side: Material frosts the backdrop away, while
            // Liquid Glass refracts and reveals the lettering bent at its edges.
            div(.class("swui-storyboard-material-stage")) {
                div(.class("swui-storyboard-material-word")) {
                    "SwiftWebUI"
                }
                div(.class("swui-storyboard-material-content")) {
                    HStack(spacing: .large) {
                        materialSample(state.control("materials", "level"))
                        glassSample(
                            variant: state.control("materials", "glass"),
                            tint: state.control("materials", "tint"),
                            shape: state.control("materials", "shape"),
                            interactive: state.controlFlag("materials", "interactive")
                        )
                    }
                    .frame(maxWidth: .infinity)
                }
            }
        default:
            Text("Hello, SwiftWebUI")
                .font(.largeTitle)
                .fontWeight(.bold)
                .foregroundStyle(.primary)
        }
    }

    @HTMLBuilder
    private func colorDemo() -> some HTML {
        let name = state.control("color", "name")
        let opacity = state.controlNumber("color", "opacity")
        let custom = Color(cssValue: state.control("color", "custom"))
        VStack(spacing: .small) {
            HStack(spacing: .medium) {
                colorChip(Color(cssValue: paletteHex(name)).opacity(opacity), label: ".\(name)")
                colorChip(custom, label: ".css")
            }
            Text("Color.\(name).opacity(\(String(format: "%.2f", opacity)))").as(.small)
                .font(Font(size: .px(12), design: .monospaced))
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .center)
    }

    private func colorChip(_ color: Color, label: String) -> some HTML {
        VStack(spacing: .xsmall) {
            VStack {}
                .frame(width: 96, height: 72)
                .background(color, in: .rect(cornerRadius: 12))
            Text(label).as(.small)
                .font(Font(size: .px(11), design: .monospaced))
                .foregroundStyle(.secondary)
        }
    }

    private func responsiveCaption(_ bp: String) -> String {
        switch bp {
        case "compact": "compact · < 600px · 1 column"
        case "regular": "regular · 600-1024px · 8 columns"
        default: "large · > 1024px · 12 columns"
        }
    }

    private func materialSample(_ level: String) -> some HTML {
        VStack(spacing: .xsmall) {
            Text("Material").font(.subheadline).fontWeight(.semibold).foregroundStyle(.primary)
            Text("\(materialLabel(level)) · blur").font(Font(size: .px(11), design: .monospaced)).foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, minHeight: 150, alignment: .center)
        .padding(.medium)
        .background(material(for: level), in: .rect(cornerRadius: 20))
    }

    private func material(for level: String) -> Material {
        switch level {
        case "ultraThin": .ultraThinMaterial
        case "thin": .thinMaterial
        case "thick": .thickMaterial
        case "ultraThick": .ultraThickMaterial
        default: .regularMaterial
        }
    }

    private func materialLabel(_ level: String) -> String {
        switch level {
        case "ultraThin": ".ultraThinMaterial"
        case "thin": ".thinMaterial"
        case "thick": ".thickMaterial"
        case "ultraThick": ".ultraThickMaterial"
        default: ".regularMaterial"
        }
    }

    private func glassSample(variant: String, tint: String, shape: String, interactive: Bool) -> some HTML {
        var glass: Glass = variant == "clear" ? .clear : .regular
        if tint != "none" {
            glass = glass.tint(storyboardTintColor(tint))
        }
        if interactive {
            glass = glass.interactive()
        }
        let clip: Shape = shape == "capsule" ? .capsule : .rect(cornerRadius: 20)
        return VStack(spacing: .xsmall) {
            Text("Liquid Glass").font(.subheadline).fontWeight(.semibold).foregroundStyle(.primary)
            Text(".glassEffect() · refracts").font(Font(size: .px(11), design: .monospaced)).foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, minHeight: 150, alignment: .center)
        .padding(.medium)
        .glassEffect(glass, in: clip)
    }

    private func gridPane(_ label: String) -> some HTML {
        Text(label).as(.small)
            .font(Font(size: .px(12), design: .monospaced))
            .foregroundStyle(.accent)
            .frame(maxWidth: .infinity, height: 56, alignment: .center)
            .background(Color.accent.opacity(0.12), in: .rect(cornerRadius: 8))
    }

    private func gridGutter(_ value: String) -> Space {
        switch value {
        case "small": return .small
        case "large": return .large
        default: return .medium
        }
    }

    /// Pane spans for an arrangement, scaled to the current column count and
    /// always summing to it so the row fills the grid.
    private func gridPanes(_ preset: String, _ cols: Int) -> [Int] {
        switch preset {
        case "halves":
            let half = cols / 2
            return [half, cols - half]
        case "thirds":
            let third = cols / 3
            return [third, third, cols - 2 * third]
        case "full":
            return [cols]
        default: // sidebar
            let main = Int((Double(cols) * 2 / 3).rounded())
            return [main, cols - main]
        }
    }

    private func paletteHex(_ name: String) -> String {
        switch name {
        case "red": return "#ff3b30"
        case "orange": return "#ff9500"
        case "yellow": return "#ffcc00"
        case "green": return "#34c759"
        case "indigo": return "#5856d6"
        case "purple": return "#af52de"
        case "pink": return "#ff2d55"
        default: return "#007aff" // blue
        }
    }

    private func typographyFont(_ value: String) -> Font {
        switch value {
        case "title": return .title
        case "headline": return .headline
        case "body": return .body
        case "footnote": return .footnote
        case "caption": return .caption
        default: return .largeTitle
        }
    }

    private func typographyWeight(_ value: String) -> Font.Weight {
        switch value {
        case "regular": return .regular
        case "medium": return .medium
        case "semibold": return .semibold
        default: return .bold
        }
    }

    private func typographyTextAlignment(_ value: String) -> TextAlignment {
        switch value {
        case "leading": return .leading
        case "trailing": return .trailing
        default: return .center
        }
    }

    private func typographyAlignment(_ value: String) -> Alignment {
        switch value {
        case "leading": return .leading
        case "trailing": return .trailing
        default: return .center
        }
    }

    private func typographyForeground(_ value: String) -> Color {
        switch value {
        case "secondary": return .secondary
        case "accent": return .accent
        case "danger": return .danger
        default: return .primary
        }
    }

    private func spacingSpace(_ value: String) -> Space {
        switch value {
        case "xsmall": return .xsmall
        case "small": return .small
        case "large": return .large
        default: return .medium
        }
    }

    private func stackHAlignment(_ value: String) -> HorizontalAlignment {
        switch value {
        case "leading": return .leading
        case "trailing": return .trailing
        default: return .center
        }
    }

    private func typographyElement(_ value: String) -> TextElement {
        switch value {
        case "span": return .span
        case "h3": return .h3
        case "code": return .code
        default: return .p
        }
    }

    private func ignoreLabel(_ ignore: String) -> String {
        switch ignore {
        case "all": return "ignoresSafeArea()"
        case "top": return "ignoresSafeArea(edges: .top)"
        default: return "safe by default"
        }
    }

    private func alignmentJustifyClass(_ value: String) -> String {
        switch value {
        case "leading": return "swui-storyboard-jc-leading"
        case "trailing": return "swui-storyboard-jc-trailing"
        default: return "swui-storyboard-jc-center"
        }
    }

    /// The monospaced caption beneath the alignment frame.
    private func alignmentTag(_ value: String) -> String {
        value == "center"
            ? "default · .center"
            : "frame(maxWidth: .infinity, alignment: .\(value))"
    }

    // The dashed frame uses typed style declarations: SwiftWebUI's
    // `.border(_:width:)` only produces a *solid* border, so the dashed style
    // lives in the Storyboard stylesheet instead of being faked with a solid
    // component border.
    @HTMLBuilder
    private func alignmentDemo(align: String, target: String) -> some HTML {
        switch target {
        case "stack":
            VStack(spacing: .small) {
                VStack(alignment: stackHAlignment(align), spacing: .xsmall) {
                    Text("Departures").fontWeight(.semibold)
                    Text("Gate 4 · on time").font(.footnote).foregroundStyle(.secondary)
                    Text("Boarding").font(.footnote).foregroundStyle(.secondary)
                }
                .padding(.small)
                .frame(width: 220, alignment: .leading)
                .background(Color.accent.opacity(0.08), in: .rect(cornerRadius: 10))
                Text("VStack(alignment: .\(align))").as(.small)
                    .font(Font(size: .px(12), design: .monospaced))
                    .foregroundStyle(.secondary)
            }
        case "multiline":
            VStack(spacing: .small) {
                Text("Wrapped lines align inside the text's own box")
                    .font(.footnote)
                    .multilineTextAlignment(typographyTextAlignment(align))
                    .frame(width: 180)
                    .padding(.small)
                    .background(Color.accent.opacity(0.08), in: .rect(cornerRadius: 10))
                Text("multilineTextAlignment(.\(align))").as(.small)
                    .font(Font(size: .px(12), design: .monospaced))
                    .foregroundStyle(.secondary)
            }
        default: // frame
            VStack(spacing: .small) {
                div(.class("swui-storyboard-alignment-frame \(alignmentJustifyClass(align))")) {
                    Text("View")
                        .fontWeight(.semibold)
                        .foregroundStyle(.accentText)
                        .padding(.horizontal, 18)
                        .padding(.vertical, 10)
                        .background(.accent, in: .rect(cornerRadius: 8))
                }
                Text(alignmentTag(align)).as(.small)
                    .font(Font(size: .px(12), design: .monospaced))
                    .foregroundStyle(.secondary)
            }
        }
    }

    @HTMLBuilder
    private func styleDemo(_ context: String) -> some HTML {
        switch context {
        case "toolbar":
            VStack(spacing: .medium) {
                Text("Content")
                    .foregroundStyle(.secondary)
                    .toolbar {
                        ToolbarItemGroup {
                            Text("Settings").fontWeight(.semibold)
                            Spacer()
                            Button("Done").buttonStyle(.borderedProminent).controlSize(.small)
                        }
                    }
                Text(".swui-toolbar .swui-text { font-weight: 600; }").as(.code)
            }
        case "list":
            VStack(spacing: .medium) {
                List {
                    Text("Wi-Fi").badge("On")
                    Text("Bluetooth").badge("Off")
                }
                Text(".swui-list .swui-text { padding-block: 2px; }").as(.code)
            }
        default: // standalone
            VStack(spacing: .medium) {
                Text("Wi-Fi")
                Text("StyleClass(\"swui-fg-primary\")").as(.code)
            }
        }
    }

    /// A device frame whose chrome insets (top/bottom) shrink the inner safe
    /// area. The hatched chrome bands and dashed accent safe-area box are
    /// storyboard stylesheet classes, not inline styles.
    private func deviceMock(_ device: String, ignore: String) -> some HTML {
        let top = safeAreaTop(device)
        let bottom = safeAreaBottom(device)
        // `all` bleeds the accent background behind every edge; `top` tints only
        // the top chrome band, matching ignoresSafeArea(edges: .top).
        return div(.class("swui-storyboard-device \(deviceClass(device))")) {
            chromeBand(edge: "top", height: top, notch: device == "notch", tinted: ignore == "all" || ignore == "top")
            chromeBand(edge: "bottom", height: bottom, notch: false, tinted: ignore == "all")
            div(.class("swui-storyboard-safe-area")) {
                Text("safe area")
                    .font(Font(size: .px(11)))
                    .fontWeight(.semibold)
                    .foregroundStyle(.accent)
            }
        }
        .background(ignore == "all" ? Color.accent.opacity(0.18) : .clear, in: .rect(cornerRadius: 12))
    }

    /// One hatched chrome band pinned to an edge of the device frame; bands at
    /// or below the 8px baseline render nothing (no chrome on that edge). A
    /// tinted band shows an accent background reaching under that chrome.
    @HTMLBuilder
    private func chromeBand(edge: String, height: Double, notch: Bool, tinted: Bool) -> some HTML {
        if height > 8 {
            div(.class("swui-storyboard-chrome-band swui-storyboard-chrome-\(edge)")) {
                if notch {
                    div(.class("swui-storyboard-notch")) {}
                } else if edge == "bottom" {
                    div(.class("swui-storyboard-home-indicator")) {}
                }
            }
            .background(tinted ? Color.accent.opacity(0.35) : .clear)
        }
    }

    private func deviceClass(_ device: String) -> String {
        switch device {
        case "browser": return "swui-storyboard-device-browser"
        case "none": return "swui-storyboard-device-none"
        default: return "swui-storyboard-device-notch"
        }
    }

    private func safeAreaTop(_ device: String) -> Double {
        switch device {
        case "browser": return 26
        case "none": return 8
        default: return 30 // notch
        }
    }

    private func safeAreaBottom(_ device: String) -> Double {
        switch device {
        case "browser": return 0
        case "none": return 8
        default: return 18 // notch
        }
    }

    private func safeAreaLabel(_ device: String) -> String {
        switch device {
        case "browser": return "Mobile browser (toolbar)"
        case "none": return "Desktop (no chrome)"
        default: return "iPhone (notch + home indicator)"
        }
    }

    private func spacingBar(_ label: String, width: Double, active: Bool) -> some HTML {
        HStack(spacing: .small) {
            Text(label).as(.small)
                .font(Font(size: .px(12), design: .monospaced))
                .foregroundStyle(.secondary)
                .frame(width: 24, alignment: .trailing)
            VStack {}
                .frame(width: width, height: 10)
                .background(active ? Color.accent : Color.border, in: .rect(cornerRadius: 3))
            if active {
                Text("selected").as(.small)
                    .font(Font(size: .px(11)))
                    .foregroundStyle(.accent)
            }
        }
    }
}
