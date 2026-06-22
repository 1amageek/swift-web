import Foundation
import SwiftHTML
import SwiftWebUI

// MARK: - Detail: Foundations

struct FoundationsDetail: Component {
    let selection: String

    var body: some HTML {
        switch selection {
        case "gridsystem":
            // Use the real GridSystem/Pane so the 8:4 spans resolve on an actual
            // 12-column grid, matching the Usage snippet below.
            GridSystem(columns: 12, gutter: .medium) {
                Pane(span: 8) { gridPane("span 8") }
                Pane(span: 4) { gridPane("span 4") }
            }
            .frame(maxWidth: .infinity)
        case "spacing":
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
                    tileGrid()
                    Text("8px grid", as: .small)
                        .font(Font(size: .px(12), design: .monospaced))
                        .foregroundStyle(.secondary)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        case "alignment":
            VStack(spacing: .small) {
                Text("View")
                    .font(Font(size: .px(12), design: .monospaced))
                    .foregroundStyle(.accent)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(Color.accent.opacity(0.16), in: .rect(cornerRadius: 6))
                    .frame(maxWidth: 240, maxHeight: 120, alignment: .center)
                    .background(.surfaceRaised, in: .rect(cornerRadius: 10))
                    .border(.border, width: 1)
                    .cornerRadius(10)
                Text("default · .center", as: .small)
                    .font(Font(size: .px(12), design: .monospaced))
                    .foregroundStyle(.secondary)
            }
        case "style":
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
                Text(".swui-list .swui-text { ... }", as: .code)
            }
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
            VStack(spacing: .small) {
                phoneMock()
                Text("iPhone (notch + home indicator)", as: .small)
                    .font(Font(size: .px(12), design: .monospaced))
                    .foregroundStyle(.secondary)
            }
        case "colorvalue":
            VStack(spacing: .small) {
                VStack {}
                    .frame(width: 120, height: 72)
                    .background(Color(hex: 0x007AFF), in: .rect(cornerRadius: 12))
                Text("Color.blue → #007AFF", as: .small)
                    .font(Font(size: .px(12), design: .monospaced))
                    .foregroundStyle(.secondary)
            }
        case "color":
            HStack(spacing: .small) {
                Button("Accent").buttonStyle(.borderedProminent)
                    .tint(.accent)
                Button("Danger").buttonStyle(.borderedProminent)
                    .tint(.danger)
                Button("Custom").buttonStyle(.borderedProminent)
                    .tint(Color(hex: 0x22A06B))
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        default:
            Text("Hello, SwiftWebUI")
                .font(.largeTitle)
                .fontWeight(.bold)
                .foregroundStyle(.primary)
        }
    }

    private func gridPane(_ label: String) -> some HTML {
        Text(label, as: .small)
            .font(Font(size: .px(12), design: .monospaced))
            .foregroundStyle(.accent)
            .frame(maxWidth: .infinity, height: 56, alignment: .center)
            .background(Color.accent.opacity(0.12), in: .rect(cornerRadius: 8))
    }

    private func tileGrid() -> some HTML {
        VStack(spacing: .xsmall) {
            ForEach(0..<4, id: \.self) { _ in
                HStack(spacing: .xsmall) {
                    ForEach(0..<4, id: \.self) { _ in
                        VStack {}
                            .frame(width: 12, height: 12)
                            .background(Color.accent.opacity(0.2), in: .rect(cornerRadius: 2))
                    }
                }
            }
        }
    }

    private func phoneMock() -> some HTML {
        // Explicit sizes so the notch pins to the top, the screen fills the
        // middle, and the home indicator pins to the bottom — without relying on
        // fill-v inside a fixed-size frame (which does not propagate).
        VStack(spacing: .small) {
            // Notch
            VStack {}
                .frame(width: 56, height: 16)
                .background(.primary, in: .rect(cornerRadius: 8))
            // Safe-area screen region
            Text("safe area")
                .font(.footnote)
                .foregroundStyle(.secondary)
                .frame(width: 136, height: 236, alignment: .center)
                .background(Color.accent.opacity(0.08), in: .rect(cornerRadius: 10))
            // Home indicator
            VStack {}
                .frame(width: 80, height: 5)
                .background(.secondary, in: .rect(cornerRadius: 3))
        }
        .padding(.small)
        .frame(width: 168)
        .background(.surfaceRaised, in: .rect(cornerRadius: 28))
        .border(.border, width: 2)
        .cornerRadius(28)
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
