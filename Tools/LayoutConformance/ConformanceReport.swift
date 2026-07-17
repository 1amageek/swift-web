#if os(macOS)
/// The comparison result for one probed rectangle.
struct ProbeComparison {
    let fixture: FixtureID
    let probe: String
    let oracle: ProbeRect?
    let web: ProbeRect?

    var maxDelta: Double? {
        guard let oracle, let web else {
            return nil
        }
        return oracle.maxDelta(to: web)
    }

    var matches: Bool {
        guard let maxDelta else {
            return false
        }
        return maxDelta <= Harness.tolerance
    }
}

enum ConformanceReport {
    static func compare(
        fixture: FixtureID,
        oracle: [String: ProbeRect],
        web: [String: ProbeRect]
    ) -> [ProbeComparison] {
        let probes = Set(oracle.keys).union(web.keys).sorted()
        return probes.map { probe in
            ProbeComparison(fixture: fixture, probe: probe, oracle: oracle[probe], web: web[probe])
        }
    }

    static func printReport(_ comparisons: [ProbeComparison]) {
        var matched = 0
        var mismatched = 0
        var currentFixture: FixtureID?

        func format(_ rect: ProbeRect?) -> String {
            guard let rect else {
                return "(missing)"
            }
            return String(
                format: "(%6.1f, %6.1f, %6.1f, %6.1f)",
                rect.x, rect.y, rect.width, rect.height
            )
        }

        for comparison in comparisons {
            if comparison.fixture != currentFixture {
                currentFixture = comparison.fixture
                print("\n=== \(comparison.fixture.rawValue) ===")
                print("probe  SwiftUI (x, y, w, h)                web (x, y, w, h)                    Δmax    verdict")
            }
            let delta = comparison.maxDelta.map { String(format: "%5.1f", $0) } ?? "    -"
            let verdict = comparison.matches ? "match" : "MISMATCH"
            if comparison.matches {
                matched += 1
            } else {
                mismatched += 1
            }
            print(
                "\(comparison.probe.padding(toLength: 6, withPad: " ", startingAt: 0)) "
                    + "\(format(comparison.oracle).padding(toLength: 35, withPad: " ", startingAt: 0)) "
                    + "\(format(comparison.web).padding(toLength: 35, withPad: " ", startingAt: 0)) "
                    + "\(delta)   \(verdict)"
            )
        }

        let total = matched + mismatched
        print("\n=== Summary ===")
        print("probes: \(total), match: \(matched), mismatch: \(mismatched), tolerance: \(Harness.tolerance)px")
    }
}
#endif
