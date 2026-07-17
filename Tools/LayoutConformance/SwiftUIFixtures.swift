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
