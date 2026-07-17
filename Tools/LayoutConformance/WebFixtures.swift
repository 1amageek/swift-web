#if os(macOS)
import SwiftHTML
import SwiftWebUI

/// SwiftWebUI renditions of the fixtures — the system under test. Boxes go
/// through SwiftWebUI's own `.frame()` lowering so the harness exercises
/// the real sizing-intent pipeline, not hand-written CSS.
enum WebFixtures {
    /// A fixed-size probe box. The probe attribute goes on the Frame
    /// wrapper (the element that carries the sizing), not the inner div.
    private static func box(_ probe: String, width: Double, height: Double) -> some HTML {
        div(.style("background: #e74c3c; width: 100%; height: 100%;"))
            .frame(width: width, height: height)
            .addingAttributes([.data("probe", probe)])
    }

    /// A probed box whose sizing under test comes from `.frame` arguments.
    private static func framedBox(
        _ probe: String,
        maxWidth: Double? = nil,
        height: Double
    ) -> some HTML {
        div(.style("background: #3498db; width: 100%; height: 100%;"))
            .frame(maxWidth: maxWidth, height: height)
            .addingAttributes([.data("probe", probe)])
    }

    @HTMLBuilder
    private static func fixture(_ id: FixtureID) -> some HTML {
        switch id {
        case .hstackSpacer:
            HStack(spacing: 0) {
                box("a", width: 80, height: 40)
                Spacer()
                box("b", width: 60, height: 40)
            }
            .frame(width: 400)

        case .hstackTwoSpacers:
            HStack(spacing: 0) {
                box("a", width: 80, height: 40)
                Spacer()
                box("b", width: 60, height: 40)
                Spacer()
                box("c", width: 40, height: 40)
            }
            .frame(width: 400)

        case .vstackSpacer:
            VStack(spacing: 0) {
                box("a", width: 80, height: 40)
                Spacer()
                box("b", width: 80, height: 60)
            }
            .frame(height: 300)

        case .spacerMinLength:
            HStack(spacing: 0) {
                box("a", width: 80, height: 40)
                Spacer(minLength: 120)
                box("b", width: 60, height: 40)
            }
            .frame(width: 260)

        case .fillInVStack:
            VStack(spacing: 0) {
                framedBox("a", maxWidth: .infinity, height: 40)
            }
            .frame(width: 400)

        case .fillInHStack:
            HStack(spacing: 0) {
                framedBox("a", maxWidth: .infinity, height: 40)
                box("b", width: 60, height: 40)
            }
            .frame(width: 400)

        case .boundedMaxCenter:
            VStack(spacing: 0) {
                framedBox("a", maxWidth: 200, height: 40)
            }
            .frame(width: 400)

        case .fixedFrame:
            box("a", width: 120, height: 48)

        case .nestedOverflow:
            HStack(spacing: 0) {
                VStack(spacing: 0) {
                    box("a", width: 300, height: 40)
                }
                box("b", width: 200, height: 40)
            }
            .frame(width: 400)

        case .nestedStacksSpacers:
            VStack(spacing: 0) {
                HStack(spacing: 0) {
                    box("a", width: 80, height: 40)
                    Spacer()
                    box("b", width: 60, height: 40)
                }
                Spacer()
                HStack(spacing: 0) {
                    box("c", width: 40, height: 40)
                    Spacer()
                    box("d", width: 80, height: 40)
                }
            }
            .frame(width: 400, height: 300)

        case .vstackAlignLeading:
            VStack(alignment: .leading, spacing: 0) {
                box("a", width: 60, height: 30)
                box("b", width: 120, height: 30)
            }

        case .vstackAlignTrailing:
            VStack(alignment: .trailing, spacing: 0) {
                box("a", width: 60, height: 30)
                box("b", width: 120, height: 30)
            }

        case .hstackAlignTop:
            HStack(alignment: .top, spacing: 0) {
                box("a", width: 60, height: 80)
                box("b", width: 60, height: 30)
            }

        case .hstackAlignBottom:
            HStack(alignment: .bottom, spacing: 0) {
                box("a", width: 60, height: 80)
                box("b", width: 60, height: 30)
            }

        case .frameAlignTopLeading:
            box("a", width: 80, height: 40)
                .frame(width: 400, height: 100, alignment: .topLeading)

        case .frameAlignBottomTrailing:
            box("a", width: 80, height: 40)
                .frame(width: 400, height: 100, alignment: .bottomTrailing)

        case .vstackSpacing:
            VStack(spacing: 24) {
                box("a", width: 80, height: 40)
                box("b", width: 80, height: 40)
            }

        case .hstackSpacing:
            HStack(spacing: 16) {
                box("a", width: 60, height: 40)
                box("b", width: 60, height: 40)
                box("c", width: 60, height: 40)
            }

        case .paddingUniform:
            VStack(spacing: 0) {
                box("a", width: 80, height: 40)
                    .padding(20)
            }

        case .zstackCenter:
            ZStack {
                box("a", width: 200, height: 100)
                box("b", width: 60, height: 30)
            }

        case .zstackBottomTrailing:
            ZStack(alignment: .bottomTrailing) {
                box("a", width: 200, height: 100)
                box("b", width: 60, height: 30)
            }

        case .minWidthFrame:
            box("a", width: 80, height: 40)
                .frame(minWidth: 150)
                .addingAttributes([.data("probe", "f")])

        case .spacersCenterV:
            VStack(spacing: 0) {
                Spacer()
                box("a", width: 80, height: 40)
                Spacer()
            }
            .frame(height: 300)

        case .spacersCenterH:
            HStack(spacing: 0) {
                Spacer()
                box("a", width: 80, height: 40)
                Spacer()
            }
            .frame(width: 400)

        case .gridRows:
            Grid(horizontalSpacing: 0, verticalSpacing: 0) {
                GridRow {
                    box("a", width: 60, height: 30)
                    box("b", width: 120, height: 30)
                }
                GridRow {
                    box("c", width: 100, height: 30)
                    box("d", width: 40, height: 30)
                }
            }

        case .lazyVGridFixed:
            LazyVGrid(columns: [GridItem(.fixed(100), spacing: 0), GridItem(.fixed(100), spacing: 0)], spacing: 0) {
                box("a", width: 80, height: 30)
                box("b", width: 80, height: 30)
                box("c", width: 80, height: 30)
            }

        case .scrollViewClip:
            ScrollView {
                VStack(spacing: 0) {
                    box("a", width: 80, height: 120)
                    box("b", width: 80, height: 120)
                    box("c", width: 80, height: 120)
                }
            }
            .frame(height: 200)
        }
    }

    /// The full HTML document for a fixture: SwiftWebUI's root stylesheet
    /// plus the fixture inside a fixed 400x300 top-leading flex container.
    /// `align-items: flex-start` gives block children SwiftUI's hug-by-
    /// default sizing instead of block-level stretch; this is the harness's
    /// root normalization, applied identically to every fixture.
    static func document(for id: FixtureID) -> String {
        let rendered = StyleRoot(colorScheme: .light) {
            div(
                .id("cr"),
                .style(
                    "width: \(Int(Harness.rootWidth))px; height: \(Int(Harness.rootHeight))px; "
                        + "display: flex; flex-direction: column; align-items: flex-start; "
                        + "position: relative; overflow: visible;"
                )
            ) {
                fixture(id)
            }
        }
        .render()

        return """
        <!doctype html>
        <html>
        <head>
        <meta charset="utf-8">
        <style>html, body { margin: 0; padding: 0; }</style>
        </head>
        <body>\(rendered)</body>
        </html>
        """
    }
}
#endif
