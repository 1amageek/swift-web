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
            // The ladder of fixed steps is constant (8 is always the base unit);
            // the right-hand tile grid is sized by the selected grid unit so the
            // 4/8/16 control visibly changes the lattice cell size.
            let unit = spacingUnit(state.control("spacing", "unit"))
            HStack(alignment: .top, spacing: .large) {
                VStack(alignment: .leading, spacing: .xsmall) {
                    spacingBar("4", width: 12, active: false)
                    spacingBar("8", width: 24, active: true)
                    spacingBar("16", width: 48, active: false)
                    spacingBar("24", width: 72, active: false)
                    spacingBar("32", width: 96, active: false)
                    spacingBar("40", width: 120, active: false)
                    spacingBar("48", width: 144, active: false)
                }
                VStack(spacing: .xsmall) {
                    tileGrid(cell: unit)
                    Text("\(Int(unit))px grid", as: .small)
                        .font(Font(size: .px(12), design: .monospaced))
                        .foregroundStyle(.secondary)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        case "alignment":
            // The chip is positioned within a bounded, dashed frame by the
            // selected alignment. The dashed frame uses typed style declarations:
            // SwiftWebUI's `.border(_:width:)` only produces a *solid* border, so
            // the dashed style cannot be expressed through it — faking it with a
            // solid border was the extra border the design rejected.
            let align = state.control("alignment", "align")
            VStack(spacing: .small) {
                div(.style {
                    .width("420px")
                    .maxWidth("80vw")
                    .height("120px")
                    .boxSizing("border-box")
                    .custom("border", "1.5px dashed var(--swui-border)")
                    .borderRadius("10px")
                    .display("flex")
                    .alignItems("center")
                    .justifyContent(alignmentJustify(align))
                    .padding("0 14px")
                }) {
                    Text("View")
                        .fontWeight(.semibold)
                        .foregroundStyle(.accentText)
                        .padding(.horizontal, 18)
                        .padding(.vertical, 10)
                        .background(.accent, in: .rect(cornerRadius: 8))
                }
                Text(alignmentTag(align), as: .small)
                    .font(Font(size: .px(12), design: .monospaced))
                    .foregroundStyle(.secondary)
            }
        case "style":
            // The same Text renders differently by context: bare, inside a List
            // row, or inside a Toolbar. The selected context drives both the demo
            // and the CSS note beneath it.
            styleDemo(state.control("style", "ctx"))
        case "responsive":
            // Show the "large" breakpoint as a real 12-column grid (three span-4
            // panes) so the lattice fills the canvas, rather than relying on a
            // multi-level flex-fill chain that collapses to intrinsic width.
            VStack(spacing: .small) {
                GridSystem(columns: 12, gutter: .medium) {
                    Pane(span: 4) { gridPane("span 4") }
                    Pane(span: 4) { gridPane("span 4") }
                    Pane(span: 4) { gridPane("span 4") }
                }
                .frame(maxWidth: .infinity)
                Text("large · > 1024px · 12 columns", as: .small)
                    .font(Font(size: .px(12), design: .monospaced))
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity)
        case "safearea":
            // The device context changes how much chrome (notch + home indicator,
            // a browser toolbar, or none) insets the safe area inside the frame.
            let device = state.control("safearea", "device")
            VStack(spacing: .small) {
                deviceMock(device)
                Text(safeAreaLabel(device), as: .small)
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
                Text("Color.\(name) · opacity \(String(format: "%.2f", opacity))", as: .small)
                    .font(Font(size: .px(12), design: .monospaced))
                    .foregroundStyle(.secondary)
            }
        case "color":
            let custom = Color(cssValue: state.control("color", "custom"))
            HStack(spacing: .small) {
                Button("Accent").buttonStyle(.borderedProminent)
                    .tint(.accent)
                Button("Danger").buttonStyle(.borderedProminent)
                    .tint(.danger)
                Button("Custom").buttonStyle(.borderedProminent)
                    .tint(custom)
            }
            .frame(maxWidth: .infinity, alignment: .center)
        case "typography":
            let text = state.control("typography", "text")
            Text(text.isEmpty ? "Hello, SwiftWebUI" : text)
                .font(typographyFont(state.control("typography", "font")))
                .fontWeight(typographyWeight(state.control("typography", "weight")))
                .multilineTextAlignment(typographyTextAlignment(state.control("typography", "align")))
                .foregroundStyle(typographyForeground(state.control("typography", "fg")))
                .frame(maxWidth: .infinity, alignment: typographyAlignment(state.control("typography", "align")))
        case "materials":
            // A soft gradient with faint typography behind, so the two effects are
            // evaluable side by side: Material frosts the backdrop away, while
            // Liquid Glass refracts and reveals the lettering bent at its edges.
            div(.style {
                .position("relative")
                .width("100%")
                .boxSizing("border-box")
                .minHeight("300px")
                .borderRadius("20px")
                .overflow("hidden")
                .display("flex")
                .alignItems("center")
                .padding("28px")
                .backgroundImage("linear-gradient(135deg, #4338ca 0%, #7c3aed 48%, #db2777 100%)")
            }) {
                div(.style {
                    .position("absolute")
                    .custom("inset", "0")
                    .display("flex")
                    .alignItems("center")
                    .justifyContent("center")
                    .custom("z-index", "0")
                    .custom("color", "rgba(255,255,255,0.22)")
                    .fontSize("96px")
                    .fontWeight("800")
                    .custom("letter-spacing", "-3px")
                    .custom("pointer-events", "none")
                    .custom("white-space", "nowrap")
                }) {
                    "SwiftWebUI"
                }
                div(.style {
                    .position("relative")
                    .custom("z-index", "1")
                    .width("100%")
                }) {
                    HStack(spacing: .large) {
                        materialSample(state.control("materials", "level"))
                        glassSample()
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

    private func glassSample() -> some HTML {
        VStack(spacing: .xsmall) {
            Text("Liquid Glass").font(.subheadline).fontWeight(.semibold).foregroundStyle(.primary)
            Text(".glassEffect() · refracts").font(Font(size: .px(11), design: .monospaced)).foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, minHeight: 150, alignment: .center)
        .padding(.medium)
        .glassEffect(.regular, in: .rect(cornerRadius: 20))
    }

    private func gridPane(_ label: String) -> some HTML {
        Text(label, as: .small)
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
        case "green": return "#34c759"
        case "orange": return "#ff9500"
        case "pink": return "#ff2d55"
        case "purple": return "#af52de"
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

    private func tileGrid(cell: Double) -> some HTML {
        VStack(spacing: .xsmall) {
            ForEach(0..<4, id: { index in index }) { _ in
                HStack(spacing: .xsmall) {
                    ForEach(0..<4, id: { index in index }) { _ in
                        VStack {}
                            .frame(width: cell, height: cell)
                            .background(Color.accent.opacity(0.2), in: .rect(cornerRadius: 2))
                    }
                }
            }
        }
    }

    /// The grid unit (cell size in px) the spacing demo lays its tile lattice on.
    private func spacingUnit(_ value: String) -> Double {
        switch value {
        case "4": return 4
        case "16": return 16
        default: return 8
        }
    }

    /// CSS `justify-content` for the alignment chip inside its bounded frame.
    private func alignmentJustify(_ value: String) -> String {
        switch value {
        case "leading": return "flex-start"
        case "trailing": return "flex-end"
        default: return "center"
        }
    }

    /// The monospaced caption beneath the alignment frame.
    private func alignmentTag(_ value: String) -> String {
        value == "center"
            ? "default · .center"
            : "frame(maxWidth: .infinity, alignment: .\(value))"
    }

    @HTMLBuilder
    private func styleDemo(_ context: String) -> some HTML {
        switch context {
        case "toolbar":
            VStack(spacing: .medium) {
                Toolbar {
                    Text("Settings").fontWeight(.semibold)
                    Spacer()
                    Button("Done").buttonStyle(.borderedProminent).controlSize(.small)
                }
                Text(".swui-toolbar .swui-text { font-weight: 600; }", as: .code)
            }
        case "list":
            VStack(spacing: .medium) {
                List {
                    ListRow {
                        Text("Wi-Fi")
                        Spacer()
                        Text("On").foregroundStyle(.secondary)
                    }
                    ListRow {
                        Text("Bluetooth")
                        Spacer()
                        Text("Off").foregroundStyle(.secondary)
                    }
                }
                Text(".swui-list .swui-text { padding-block: 2px; }", as: .code)
            }
        default: // standalone
            VStack(spacing: .medium) {
                Text("Wi-Fi")
                Text(".swui-text { color: var(--swui-text); }", as: .code)
            }
        }
    }

    /// A device frame whose chrome insets (top/bottom) shrink the inner safe
    /// area. The hatched chrome bands and dashed accent safe-area box need inline
    /// CSS, so the frame is emitted as raw markup matching the reference.
    private func deviceMock(_ device: String) -> some HTML {
        let top = safeAreaTop(device)
        let bottom = safeAreaBottom(device)
        return div(.style {
            .position("relative")
            .width("188px")
            .height("300px")
            .custom("border", "6px solid var(--swui-text)")
            .borderRadius("30px")
            .overflow("hidden")
            .background("var(--swui-surface-raised)")
        }) {
            chromeBand(edge: "top", height: top, notch: device == "notch")
            chromeBand(edge: "bottom", height: bottom, notch: false)
            div(.style {
                .position("absolute")
                .custom("top", "\(Int(top))px")
                .custom("bottom", "\(Int(bottom))px")
                .custom("left", "8px")
                .custom("right", "8px")
                .custom("border", "1.5px dashed color-mix(in srgb, var(--swui-accent) 55%, transparent)")
                .borderRadius("8px")
                .background("color-mix(in srgb, var(--swui-accent) 9%, transparent)")
                .display("flex")
                .alignItems("center")
                .justifyContent("center")
            }) {
                Text("safe area")
                    .font(Font(size: .px(11)))
                    .fontWeight(.semibold)
                    .foregroundStyle(.accent)
            }
        }
    }

    /// One hatched chrome band pinned to an edge of the device frame; bands at
    /// or below the 8px baseline render nothing (no chrome on that edge).
    @HTMLBuilder
    private func chromeBand(edge: String, height: Double, notch: Bool) -> some HTML {
        if height > 8 {
            div(.style {
                .position("absolute")
                .custom(edge, "0")
                .custom("left", "0")
                .custom("right", "0")
                .height("\(Int(height))px")
                .background("repeating-linear-gradient(45deg, color-mix(in srgb, var(--swui-text-muted) 22%, transparent), color-mix(in srgb, var(--swui-text-muted) 22%, transparent) 4px, transparent 4px, transparent 8px)")
            }) {
                if notch {
                    div(.style {
                        .width("96px")
                        .height("18px")
                        .background("#000")
                        .borderRadius("0 0 12px 12px")
                        .margin("0 auto")
                    }) {}
                } else if edge == "bottom" {
                    div(.style {
                        .width("90px")
                        .height("4px")
                        .borderRadius("2px")
                        .background("var(--swui-text-muted)")
                        .margin("7px auto 0")
                        .opacity("0.6")
                    }) {}
                }
            }
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
            Text(label, as: .small)
                .font(Font(size: .px(12), design: .monospaced))
                .foregroundStyle(.secondary)
                .frame(width: 24, alignment: .trailing)
            VStack {}
                .frame(width: width, height: 10)
                .background(active ? Color.accent : Color.border, in: .rect(cornerRadius: 3))
            if active {
                Text("base unit", as: .small)
                    .font(Font(size: .px(11)))
                    .foregroundStyle(.accent)
            }
        }
    }
}
