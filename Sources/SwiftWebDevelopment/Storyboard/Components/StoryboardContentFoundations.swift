import Foundation
import SwiftHTML
import SwiftWebUI

// Editorial content for the Foundations category.

func foundationsDiscussion(for id: String) -> [String]? {
    switch id {
    case "gridsystem":
        return [
            "GridSystem divides the content canvas into a fixed number of fractional columns — conventionally 4, 8, or 12 — separated by a gutter from the spacing scale. Pane(span:) children claim whole columns, and a span that exceeds the remaining row wraps onto the next one, so every arrangement stays on the lattice instead of accumulating ad-hoc widths.",
            "The grid lowers to CSS Grid (repeat(columns, minmax(0, 1fr))), so the browser solves track sizing and the same span arrangement holds at any container width. Use it for page-level composition — sidebars, split content, card decks; stacks own the arrangement inside a component.",
        ]
    case "spacing":
        return [
            "Every gap, inset, and offset resolves from a named token — .xsmall (4px) through .xlarge (24px) — built on an 8px base unit. Tokens resolve through the active style system to CSS custom properties, so retheming rescales the whole page's rhythm at once instead of hunting down pixel values.",
            "Pass tokens to stack spacing and padding for anything structural. Numeric spacing stays SwiftUI-canonical — points lower to px — for one-off fine tuning; if a gap is not a token, it should be a deliberate exception, not a habit.",
        ]
    case "alignment":
        return [
            "A view placed on its own is centered in the space it is given — the SwiftUI default. frame(alignment:) positions content inside the box the frame claims, and stack alignment does the same for children on the cross axis; there is no separate alignment system to learn.",
            "On the web every alignment lowers to flexbox justify/align declarations, so the browser positions content and no Swift-side solver runs. Reach for frame(maxWidth: .infinity, alignment:) to pin content inside a fill, and multilineTextAlignment(_:) to align wrapped lines inside the text's own box.",
        ]
    case "hug-fill":
        return [
            "Every component either hugs its intrinsic content — the default, as in SwiftUI — or opts into filling the width its parent offers with frame(maxWidth: .infinity). fixedSize() pins a view back to its ideal size when a container would otherwise stretch it.",
            "The intent lowers to flex hug/fill marker classes, so the browser negotiates sizes without a measurement pass in Swift. Filling makes the frame greedy, not the control: the control keeps its intrinsic size and the frame's alignment positions it inside the claimed width.",
        ]
    case "style":
        return [
            "Components emit stable semantic classes — swui-text, swui-list, swui-toolbar — and no inline styles. The active style system compiles every token and recipe into one static stylesheet, so a page's appearance is data the cascade resolves, not code that runs per node.",
            "Contextual styling flows through that cascade: a rule like .swui-toolbar .swui-text restyles text inside a bar without the call site changing. The same Text declaration renders differently bare, in a list row, or in a toolbar — the context, not the component, decides.",
        ]
    case "responsive":
        return [
            "Layout responds to width through three size classes — compact below 600px, regular up to 1024px, and large above — rather than scaling continuously. Each class changes the lattice itself: column count, gutter, and margins, so content reflows instead of shrinking.",
            "The classes lower to CSS media queries in the static stylesheet: the server renders one document and the browser switches layout at the breakpoints, with no resize handler or client code involved.",
        ]
    case "safearea":
        return [
            "The root scene pads content away from device and browser chrome — notches, home indicators, toolbars — using env(safe-area-inset-*) with viewport-fit=cover, so content is safe by default without per-view work.",
            "ignoresSafeArea() opts a single element out, letting a background or hero extend edge-to-edge behind the chrome while foreground content stays inset. Combine the two in a ZStack: the background ignores the safe area, the content does not.",
        ]
    case "materials":
        return [
            "Material frosts the backdrop: a blur plus a tint that trades context for legibility, in five levels from ultraThin to ultraThick. Liquid Glass refracts instead — a light blur with edge lensing, a specular sheen, and a rim that reveals what is behind rather than hiding it. Glass is the default surface for chrome that floats above content.",
            "On the web, Material lowers to backdrop-filter and Liquid Glass layers an SVG refraction recipe on top. Both are surfaces, not colors: apply them with background(_:in:) or glassEffect(_:in:) and let the shape clip the effect.",
        ]
    default:
        return nil
    }
}

func foundationsParity(for id: String) -> String? {
    switch id {
    case "gridsystem":
        return "SwiftUI has no page-lattice primitive — Grid and LazyVGrid size to content; GridSystem is column-count-first, with panes claiming whole fractional tracks."
    case "spacing":
        return "Same shape as SwiftUI's spacing parameters (VStack(spacing:), .padding(_:)); the web adds named tokens that resolve through the style system, while plain numbers lower to px."
    case "alignment":
        return "Same shape as SwiftUI's Alignment and frame(_:alignment:); on the web the vocabulary lowers to flexbox justify/align markers that the browser solves."
    case "hug-fill":
        return "Same shape as SwiftUI's fixedSize() and frame(maxWidth: .infinity); the web lowers the intent to flex hug/fill markers instead of a proposal-and-response layout pass."
    case "style":
        return "Plays the role of SwiftUI's environment-driven styling (buttonStyle, listStyle): the context around a view decides its appearance, and on the web that environment is the CSS cascade."
    case "responsive":
        return "Plays the role of SwiftUI's horizontalSizeClass — discrete width classes rather than continuous scaling — lowered to CSS media queries, so layout switches without client code."
    case "safearea":
        return "Same shape as SwiftUI's ignoresSafeArea(_:edges:); on the web the insets come from CSS env(safe-area-inset-*) rather than the device SDK."
    case "materials":
        return "Same shape as SwiftUI's Material levels and glassEffect(_:in:); the web renders them with backdrop-filter plus an SVG refraction recipe instead of the system compositor."
    default:
        return nil
    }
}

func foundationsVariants(for id: String) -> [CatalogVariant]? {
    switch id {
    case "gridsystem":
        return [
            CatalogVariant("Halves", detail: "Two span-2 panes split a 4-column canvas evenly.") {
                GridSystem(columns: 4, gutter: .small, verticalPadding: .none) {
                    Pane(span: 2) { foundationsGridCell("2") }
                    Pane(span: 2) { foundationsGridCell("2") }
                }
                .frame(width: 240)
            },
            CatalogVariant("Sidebar", detail: "A span-3 content pane against a span-1 rail.") {
                GridSystem(columns: 4, gutter: .small, verticalPadding: .none) {
                    Pane(span: 3) { foundationsGridCell("3") }
                    Pane(span: 1) { foundationsGridCell("1") }
                }
                .frame(width: 240)
            },
            CatalogVariant("Quarters", detail: "One pane per track; the gutter, not padding, separates them.") {
                GridSystem(columns: 4, gutter: .small, verticalPadding: .none) {
                    Pane(span: 1) { foundationsGridCell("1") }
                    Pane(span: 1) { foundationsGridCell("1") }
                    Pane(span: 1) { foundationsGridCell("1") }
                    Pane(span: 1) { foundationsGridCell("1") }
                }
                .frame(width: 240)
            },
            CatalogVariant("Wrapping", detail: "A span that exceeds the remaining row wraps onto the next one.") {
                GridSystem(columns: 4, gutter: .small, verticalPadding: .none) {
                    Pane(span: 2) { foundationsGridCell("2", height: 20) }
                    Pane(span: 2) { foundationsGridCell("2", height: 20) }
                    Pane(span: 4) { foundationsGridCell("4", height: 20) }
                }
                .frame(width: 240)
            },
            CatalogVariant("Gutter scale", detail: "The gutter is a spacing token — .small above, .large below — never ad-hoc pixels.") {
                VStack(spacing: .small) {
                    GridSystem(columns: 4, gutter: .small, verticalPadding: .none) {
                        Pane(span: 1) { foundationsGridCell("", height: 16) }
                        Pane(span: 1) { foundationsGridCell("", height: 16) }
                        Pane(span: 1) { foundationsGridCell("", height: 16) }
                        Pane(span: 1) { foundationsGridCell("", height: 16) }
                    }
                    .frame(width: 240)
                    GridSystem(columns: 4, gutter: .large, verticalPadding: .none) {
                        Pane(span: 1) { foundationsGridCell("", height: 16) }
                        Pane(span: 1) { foundationsGridCell("", height: 16) }
                        Pane(span: 1) { foundationsGridCell("", height: 16) }
                        Pane(span: 1) { foundationsGridCell("", height: 16) }
                    }
                    .frame(width: 240)
                }
            },
        ]
    case "spacing":
        return [
            CatalogVariant("Gap scale", detail: "The named tokens — 4, 8, 12, and 16px on the 8px base unit.") {
                VStack(alignment: .leading, spacing: .xsmall) {
                    foundationsGapRow(".xsmall", spacing: .xsmall)
                    foundationsGapRow(".small", spacing: .small)
                    foundationsGapRow(".medium", spacing: .medium)
                    foundationsGapRow(".large", spacing: .large)
                }
            },
            CatalogVariant("Padding tokens", detail: "The same tokens drive insets, so gaps and padding share one rhythm.") {
                HStack(alignment: .top, spacing: .small) {
                    foundationsPaddedChip(".small", padding: .small)
                    foundationsPaddedChip(".medium", padding: .medium)
                    foundationsPaddedChip(".large", padding: .large)
                }
            },
            CatalogVariant("Stack rhythm", detail: "Stack spacing sets density: .xsmall packs rows, .large lets them breathe.") {
                HStack(alignment: .top, spacing: .large) {
                    VStack(spacing: .xsmall) {
                        VStack(spacing: .xsmall) {
                            foundationsRhythmBar()
                            foundationsRhythmBar()
                            foundationsRhythmBar()
                        }
                        foundationsSpacingCaption(".xsmall")
                    }
                    VStack(spacing: .xsmall) {
                        VStack(spacing: .large) {
                            foundationsRhythmBar()
                            foundationsRhythmBar()
                            foundationsRhythmBar()
                        }
                        foundationsSpacingCaption(".large")
                    }
                }
            },
            CatalogVariant("Numeric spacing", detail: "Plain numbers stay SwiftUI-canonical: points lower to px for one-off tuning.") {
                VStack(spacing: .xsmall) {
                    HStack(spacing: 20) {
                        foundationsSpacingBlock()
                        foundationsSpacingBlock()
                    }
                    foundationsSpacingCaption("HStack(spacing: 20)")
                }
            },
        ]
    case "alignment":
        return [
            CatalogVariant("Default (.center)", detail: "A lone view is centered in the space it is given.") {
                foundationsAlignmentChip(.center)
            },
            CatalogVariant(".leading", detail: "frame(alignment: .leading) pins content to the leading edge of the claimed box.") {
                foundationsAlignmentChip(.leading)
            },
            CatalogVariant(".trailing", detail: "frame(alignment: .trailing) pins content to the trailing edge.") {
                foundationsAlignmentChip(.trailing)
            },
            CatalogVariant("Stack cross axis", detail: "VStack(alignment: .leading) aligns children of different widths on the cross axis.") {
                VStack(alignment: .leading, spacing: .xsmall) {
                    Text("Departures").fontWeight(.semibold)
                    Text("Gate 4 · on time").font(.footnote).foregroundStyle(.secondary)
                    Text("Boarding").font(.footnote).foregroundStyle(.secondary)
                }
                .padding(.small)
                .background(Color.accent.opacity(0.08), in: .rect(cornerRadius: 10))
            },
            CatalogVariant("multilineTextAlignment", detail: "Aligns wrapped lines inside the text's own box, independent of frame alignment.") {
                Text("Wrapped lines align inside the text box")
                    .font(.caption)
                    .multilineTextAlignment(.trailing)
                    .frame(width: 140)
            },
        ]
    case "hug-fill":
        return [
            CatalogVariant("Hug (default)", detail: "The control sizes to its label; the rule shows the width on offer.") {
                VStack(alignment: .leading, spacing: .small) {
                    foundationsLaneRule()
                    Button("Fixed") {}.buttonStyle(.bordered)
                }
            },
            CatalogVariant(".frame(maxWidth: .infinity)", detail: "The frame claims the full width; the control keeps its intrinsic size inside it.") {
                VStack(alignment: .leading, spacing: .small) {
                    foundationsLaneRule()
                    Button("Flexible") {}
                        .buttonStyle(.borderedProminent)
                        .frame(maxWidth: .infinity)
                        .background(Color.accent.opacity(0.08), in: .rect(cornerRadius: 8))
                }
            },
            CatalogVariant("Fill with alignment", detail: "The frame's alignment positions the control inside the claimed width.") {
                VStack(alignment: .leading, spacing: .small) {
                    foundationsLaneRule()
                    Button("Flexible") {}
                        .buttonStyle(.borderedProminent)
                        .frame(maxWidth: .infinity, alignment: .trailing)
                        .background(Color.accent.opacity(0.08), in: .rect(cornerRadius: 8))
                }
            },
            CatalogVariant("Fill in a row", detail: "One fill child takes the width the row has left over.") {
                VStack(alignment: .leading, spacing: .small) {
                    foundationsLaneRule()
                    HStack(spacing: .small) {
                        Button("Cancel") {}.buttonStyle(.bordered)
                        Button("Continue") {}
                            .buttonStyle(.borderedProminent)
                            .frame(maxWidth: .infinity)
                            .background(Color.accent.opacity(0.08), in: .rect(cornerRadius: 8))
                    }
                }
            },
        ]
    case "style":
        return [
            CatalogVariant("Bare", detail: "Only .swui-text applies; the base stylesheet decides the appearance.") {
                Text("Wi-Fi")
            },
            CatalogVariant("List row", detail: ".swui-list .swui-text — the row context restyles the same declaration.") {
                List {
                    Text("Wi-Fi").badge("On")
                    Text("Bluetooth").badge("Off")
                }
            },
            CatalogVariant("Toolbar", detail: ".swui-toolbar .swui-text picks up bar typography without the call site changing.") {
                Text("Content")
                    .foregroundStyle(.secondary)
                    .toolbar {
                        ToolbarItemGroup {
                            Text("Settings").fontWeight(.semibold)
                            Spacer()
                            Button("Done") {}.buttonStyle(.borderedProminent).controlSize(.small)
                        }
                    }
            },
        ]
    case "responsive":
        return [
            CatalogVariant("compact", detail: "Below 600px the lattice collapses to a single stacked column.") {
                GridSystem(columns: 1, gutter: .small, verticalPadding: .none) {
                    Pane(span: 1) { foundationsGridCell("1", height: 18) }
                    Pane(span: 1) { foundationsGridCell("1", height: 18) }
                    Pane(span: 1) { foundationsGridCell("1", height: 18) }
                }
                .frame(width: 140)
            },
            CatalogVariant("regular", detail: "From 600px to 1024px an 8-column grid carries two span-4 panes.") {
                GridSystem(columns: 8, gutter: .small, verticalPadding: .none) {
                    Pane(span: 4) { foundationsGridCell("4") }
                    Pane(span: 4) { foundationsGridCell("4") }
                }
                .frame(width: 240)
            },
            CatalogVariant("large", detail: "Above 1024px a 12-column grid fits three span-4 panes per row.") {
                GridSystem(columns: 12, gutter: .small, verticalPadding: .none) {
                    Pane(span: 4) { foundationsGridCell("4") }
                    Pane(span: 4) { foundationsGridCell("4") }
                    Pane(span: 4) { foundationsGridCell("4") }
                }
                .frame(width: 240)
            },
        ]
    case "safearea":
        return [
            CatalogVariant("Safe by default", detail: "The root scene insets content between the chrome bands; no per-view work.") {
                VStack(spacing: 0) {
                    foundationsChromeBand(height: 12)
                    foundationsSafeAreaLabel()
                        .frame(width: 120, height: 52)
                        .background(Color.accent.opacity(0.12))
                    foundationsChromeBand(height: 10)
                }
                .clipShape(.rect(cornerRadius: 10))
            },
            CatalogVariant("ignoresSafeArea()", detail: "A background that ignores the safe area reaches every edge, behind both bands; content stays inset.") {
                VStack(spacing: 0) {
                    foundationsChromeBand(height: 12)
                    foundationsSafeAreaLabel()
                        .frame(width: 120, height: 52)
                    foundationsChromeBand(height: 10)
                }
                .background(Color.accent.opacity(0.2))
                .clipShape(.rect(cornerRadius: 10))
            },
            CatalogVariant("ignoresSafeArea(edges: .top)", detail: "Extends under the top chrome only; the bottom inset still applies.") {
                VStack(spacing: 0) {
                    VStack(spacing: 0) {
                        foundationsChromeBand(height: 12)
                        foundationsSafeAreaLabel()
                            .frame(width: 120, height: 52)
                    }
                    .background(Color.accent.opacity(0.2))
                    foundationsChromeBand(height: 10)
                }
                .clipShape(.rect(cornerRadius: 10))
            },
        ]
    case "materials":
        return [
            CatalogVariant("Frost vs refraction", detail: "Material obscures the scene behind it; Liquid Glass bends it at the edges.") {
                HStack(spacing: .medium) {
                    foundationsSurfaceLabel("Material")
                        .background(.regularMaterial, in: .rect(cornerRadius: 10))
                    foundationsSurfaceLabel("Glass")
                        .glassEffect(.regular, in: .rect(cornerRadius: 10))
                }
            },
            CatalogVariant("Material levels", detail: "Opacity steps from .ultraThinMaterial to .ultraThickMaterial; pick the lightest level that keeps content legible.") {
                HStack(spacing: .xsmall) {
                    foundationsMaterialSwatch(.ultraThinMaterial)
                    foundationsMaterialSwatch(.thinMaterial)
                    foundationsMaterialSwatch(.regularMaterial)
                    foundationsMaterialSwatch(.thickMaterial)
                    foundationsMaterialSwatch(.ultraThickMaterial)
                }
            },
            CatalogVariant(".regular vs .clear", detail: ".clear lets more of the scene through than .regular; both keep the lensed rim.") {
                HStack(spacing: .medium) {
                    foundationsSurfaceLabel("Regular")
                        .glassEffect(.regular, in: .capsule)
                    foundationsSurfaceLabel("Clear")
                        .glassEffect(.clear, in: .capsule)
                }
            },
            CatalogVariant("Tinted glass", detail: "tint(_:) washes the fill while refraction and rim stay intact.") {
                HStack(spacing: .medium) {
                    foundationsSurfaceLabel("Blue")
                        .glassEffect(.regular.tint(.blue), in: .capsule)
                    foundationsSurfaceLabel("Pink")
                        .glassEffect(.regular.tint(.pink), in: .capsule)
                }
            },
            CatalogVariant("Shapes", detail: "The shape clips both the fill and the refraction — capsule or rounded rect.") {
                HStack(spacing: .medium) {
                    foundationsSurfaceLabel("Capsule")
                        .glassEffect(.regular, in: .capsule)
                    foundationsSurfaceLabel("Rect")
                        .glassEffect(.regular, in: .rect(cornerRadius: 12))
                }
            },
            CatalogVariant("Interactive", detail: ".interactive() adds pointer hover and press highlights to the surface.") {
                foundationsSurfaceLabel("Hover me")
                    .glassEffect(.regular.interactive(), in: .capsule)
            },
        ]
    default:
        return nil
    }
}

// MARK: - Demo helpers

/// A labelled cell that fills its grid track, making spans evaluable.
private func foundationsGridCell(_ label: String, height: Double = 26) -> some HTML {
    Text(label, as: .small)
        .font(Font(size: .px(11), design: .monospaced))
        .foregroundStyle(.accent)
        .frame(maxWidth: .infinity, height: height, alignment: .center)
        .background(Color.accent.opacity(0.14), in: .rect(cornerRadius: 6))
}

/// One row of the gap scale: a token label and a block pair separated by it.
private func foundationsGapRow(_ label: String, spacing: Space) -> some HTML {
    HStack(spacing: .small) {
        foundationsSpacingCaption(label)
            .frame(width: 60, alignment: .trailing)
        HStack(spacing: spacing) {
            foundationsSpacingBlock()
            foundationsSpacingBlock()
        }
    }
}

private func foundationsSpacingBlock() -> some HTML {
    VStack {}
        .frame(width: 20, height: 20)
        .background(Color.accent.opacity(0.35), in: .rect(cornerRadius: 6))
}

private func foundationsSpacingCaption(_ label: String) -> some HTML {
    Text(label, as: .small)
        .font(Font(size: .px(11), design: .monospaced))
        .foregroundStyle(.secondary)
}

/// A chip whose inset grows with the padding token it names.
private func foundationsPaddedChip(_ label: String, padding: Space) -> some HTML {
    Text(label, as: .small)
        .font(Font(size: .px(11), design: .monospaced))
        .foregroundStyle(.accent)
        .padding(padding)
        .background(Color.accent.opacity(0.12), in: .rect(cornerRadius: 8))
}

private func foundationsRhythmBar() -> some HTML {
    VStack {}
        .frame(width: 56, height: 8)
        .background(Color.accent.opacity(0.3), in: .rect(cornerRadius: 3))
}

/// A chip positioned by the given alignment inside a visible bounded frame.
private func foundationsAlignmentChip(_ alignment: Alignment) -> some HTML {
    Text("View")
        .font(Font(size: .px(12), weight: .semibold))
        .foregroundStyle(.accentText)
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(.accent, in: .rect(cornerRadius: 7))
        .frame(width: 200, height: 56, alignment: alignment)
        .background(Color.accent.opacity(0.08), in: .rect(cornerRadius: 10))
}

/// A hairline that fixes the width on offer, so hug and fill are comparable.
private func foundationsLaneRule() -> some HTML {
    VStack {}
        .frame(width: 210, height: 3)
        .background(Color.border, in: .capsule)
}

/// A hatched-chrome stand-in: the band a notch, toolbar, or home indicator occupies.
private func foundationsChromeBand(height: Double) -> some HTML {
    VStack {}
        .frame(width: 120, height: height)
        .background(Color.primary.opacity(0.18))
}

private func foundationsSafeAreaLabel() -> some HTML {
    Text("safe area")
        .font(Font(size: .px(10), weight: .semibold))
        .foregroundStyle(.accent)
}

/// The label content shared by the material and glass surface demos.
private func foundationsSurfaceLabel(_ label: String) -> some HTML {
    Text(label)
        .font(Font(size: .px(12), weight: .semibold))
        .foregroundStyle(.primary)
        .padding(.horizontal, 14)
        .padding(.vertical, 8)
}

private func foundationsMaterialSwatch(_ material: Material) -> some HTML {
    VStack {}
        .frame(width: 32, height: 44)
        .background(material, in: .rect(cornerRadius: 8))
}
