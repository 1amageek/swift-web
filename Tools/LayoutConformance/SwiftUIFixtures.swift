#if os(macOS)
import SwiftUI
import Synchronization

/// Collects probed frames during SwiftUI layout. GeometryReader bodies run
/// on the main thread during layout; the Mutex keeps the store Sendable
/// without pulling actor isolation into view bodies.
final class ProbeStore: Sendable {
    static let shared = ProbeStore()

    private let frames = Mutex<[String: ProbeRect]>([:])

    func reset() {
        frames.withLock { $0.removeAll() }
    }

    func record(_ id: String, _ rect: CGRect) {
        let probe = ProbeRect(x: rect.minX, y: rect.minY, width: rect.width, height: rect.height)
        frames.withLock { $0[id] = probe }
    }

    func snapshot() -> [String: ProbeRect] {
        frames.withLock { $0 }
    }
}

private let rootSpace = "conformance-root"

@MainActor
extension View {
    /// Records this view's frame in the fixture root's coordinate space.
    func probe(_ id: String) -> some View {
        background(
            GeometryReader { proxy -> Color in
                ProbeStore.shared.record(id, proxy.frame(in: .named(rootSpace)))
                return Color.clear
            }
        )
    }
}

/// SwiftUI renditions of the fixtures — the oracle.
@MainActor
enum SwiftUIFixtures {
    private static func box(_ probe: String, width: Double, height: Double) -> some View {
        Color(red: 0.9, green: 0.3, blue: 0.24)
            .frame(width: width, height: height)
            .probe(probe)
    }

    @ViewBuilder
    private static func fixture(_ id: FixtureID) -> some View {
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
                Color(red: 0.2, green: 0.6, blue: 0.86)
                    .frame(height: 40)
                    .frame(maxWidth: .infinity)
                    .probe("a")
            }
            .frame(width: 400)

        case .fillInHStack:
            HStack(spacing: 0) {
                Color(red: 0.2, green: 0.6, blue: 0.86)
                    .frame(height: 40)
                    .frame(maxWidth: .infinity)
                    .probe("a")
                box("b", width: 60, height: 40)
            }
            .frame(width: 400)

        case .boundedMaxCenter:
            VStack(spacing: 0) {
                Color(red: 0.2, green: 0.6, blue: 0.86)
                    .frame(height: 40)
                    .frame(maxWidth: 200)
                    .probe("a")
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
                .probe("f")

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

        case .nestedFillChain:
            HStack(spacing: 0) {
                VStack(spacing: 0) {
                    Color(red: 0.2, green: 0.6, blue: 0.86)
                        .frame(height: 40)
                        .frame(maxWidth: .infinity)
                        .probe("a")
                }
                box("b", width: 60, height: 40)
            }
            .frame(width: 400)

        case .nestedSpacerDepth:
            VStack(spacing: 0) {
                HStack(spacing: 0) {
                    box("a", width: 60, height: 40)
                    Spacer()
                    VStack(spacing: 0) {
                        box("b", width: 40, height: 20)
                        Spacer()
                        box("c", width: 40, height: 20)
                    }
                    .frame(height: 120)
                }
                Spacer()
                box("d", width: 80, height: 40)
            }
            .frame(width: 400, height: 300)

        case .zstackNestedStack:
            ZStack {
                box("a", width: 200, height: 120)
                VStack(spacing: 0) {
                    box("b", width: 40, height: 20)
                    Spacer()
                    box("c", width: 40, height: 20)
                }
                .frame(height: 80)
            }

        case .scrollInVStack:
            VStack(spacing: 0) {
                ScrollView {
                    VStack(spacing: 0) {
                        box("a", width: 80, height: 120)
                        box("b", width: 80, height: 120)
                    }
                }
                .frame(height: 150)
                Spacer()
                box("c", width: 60, height: 40)
            }
            .frame(height: 300)

        case .gridInHStack:
            HStack(spacing: 0) {
                Grid(horizontalSpacing: 0, verticalSpacing: 0) {
                    GridRow {
                        box("a", width: 60, height: 30)
                        box("b", width: 90, height: 30)
                    }
                    GridRow {
                        box("c", width: 80, height: 30)
                        box("d", width: 40, height: 30)
                    }
                }
                Spacer()
                box("e", width: 60, height: 40)
            }
            .frame(width: 400)

        case .siblingSpacerRows:
            HStack(spacing: 0) {
                HStack(spacing: 0) {
                    box("a", width: 60, height: 40)
                    Spacer()
                }
                HStack(spacing: 0) {
                    Spacer()
                    box("b", width: 60, height: 40)
                }
            }
            .frame(width: 400)

        case .siblingSpacerColumns:
            VStack(spacing: 0) {
                VStack(spacing: 0) {
                    box("a", width: 80, height: 30)
                    Spacer()
                }
                VStack(spacing: 0) {
                    Spacer()
                    box("b", width: 80, height: 30)
                }
            }
            .frame(height: 300)

        case .paddedFillInHStack:
            HStack(spacing: 0) {
                Color(red: 0.2, green: 0.6, blue: 0.86)
                    .frame(height: 40)
                    .frame(maxWidth: .infinity)
                    .probe("a")
                    .padding(20)
                box("b", width: 60, height: 40)
            }
            .frame(width: 400)

        case .paddedFillInVStack:
            VStack(spacing: 0) {
                Color(red: 0.2, green: 0.6, blue: 0.86)
                    .frame(height: 40)
                    .frame(maxWidth: .infinity)
                    .probe("a")
                    .padding(20)
            }
            .frame(width: 400)

        case .siblingFillRows:
            HStack(spacing: 0) {
                HStack(spacing: 0) {
                    Color(red: 0.2, green: 0.6, blue: 0.86)
                        .frame(height: 40)
                        .frame(maxWidth: .infinity)
                        .probe("a")
                }
                box("b", width: 60, height: 40)
            }
            .frame(width: 400)

        case .spacerColumnInHStack:
            HStack(spacing: 0) {
                VStack(spacing: 0) {
                    box("a", width: 60, height: 30)
                    Spacer()
                }
                box("b", width: 60, height: 40)
            }
            .frame(height: 200)

        case .paddedSpacerRowInVStack:
            VStack(spacing: 0) {
                HStack(spacing: 0) {
                    box("a", width: 60, height: 40)
                    Spacer()
                    box("b", width: 60, height: 40)
                }
                .padding(10)
                box("c", width: 80, height: 40)
            }
            .frame(width: 400)

        case .paddedFillVInVStack:
            VStack(spacing: 0) {
                Color(red: 0.2, green: 0.6, blue: 0.86)
                    .frame(width: 80)
                    .frame(maxHeight: .infinity)
                    .probe("a")
                    .padding(20)
                box("b", width: 60, height: 40)
            }
            .frame(height: 300)

        case .doublePaddedFillInHStack:
            HStack(spacing: 0) {
                Color(red: 0.2, green: 0.6, blue: 0.86)
                    .frame(height: 40)
                    .frame(maxWidth: .infinity)
                    .probe("a")
                    .padding(20)
                    .padding(20)
                box("b", width: 60, height: 40)
            }
            .frame(width: 400)

        case .deepFillChain:
            HStack(spacing: 0) {
                VStack(spacing: 0) {
                    VStack(spacing: 0) {
                        Color(red: 0.2, green: 0.6, blue: 0.86)
                            .frame(height: 40)
                            .frame(maxWidth: .infinity)
                            .probe("a")
                    }
                }
                box("b", width: 60, height: 40)
            }
            .frame(width: 400)

        case .deepSpacerRows:
            HStack(spacing: 0) {
                HStack(spacing: 0) {
                    HStack(spacing: 0) {
                        box("a", width: 60, height: 40)
                        Spacer()
                    }
                }
                box("b", width: 60, height: 40)
            }
            .frame(width: 400)

        case .fillInFixedFrame:
            VStack(spacing: 0) {
                VStack(spacing: 0) {
                    Color(red: 0.2, green: 0.6, blue: 0.86)
                        .frame(height: 30)
                        .frame(maxWidth: .infinity)
                        .probe("a")
                }
                .frame(width: 100)
                .probe("f")
                box("b", width: 200, height: 40)
            }
            .frame(width: 400)
        }
    }

    /// The fixture inside the same 400x300 top-leading container the web
    /// side uses, with the probe coordinate space on the container.
    static func rootView(for id: FixtureID) -> AnyView {
        AnyView(
            ZStack(alignment: .topLeading) {
                fixture(id)
            }
            .frame(
                width: Harness.rootWidth,
                height: Harness.rootHeight,
                alignment: .topLeading
            )
            .coordinateSpace(name: rootSpace)
        )
    }
}
#endif
