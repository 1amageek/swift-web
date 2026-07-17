#if os(macOS)
import AppKit

// The harness needs an app context for AppKit/WebKit layout, but never
// shows UI.
_ = NSApplication.shared
NSApplication.shared.setActivationPolicy(.prohibited)

let comparisons: [ProbeComparison] = MainActor.assumeIsolated {
    let webKit = WebKitMeasurement()
    var all: [ProbeComparison] = []
    for fixture in FixtureID.allCases {
        let oracle = OracleMeasurement.measure(fixture)
        let document = WebFixtures.document(for: fixture)
        do {
            let web = try webKit.measure(document: document)
            all.append(contentsOf: ConformanceReport.compare(fixture: fixture, oracle: oracle, web: web))
        } catch {
            print("ERROR measuring \(fixture.rawValue) in WebKit: \(error)")
            all.append(
                contentsOf: ConformanceReport.compare(fixture: fixture, oracle: oracle, web: [:])
            )
        }
    }
    return all
}

ConformanceReport.printReport(comparisons)
#else
fatalError("The layout conformance harness requires macOS (SwiftUI + WebKit).")
#endif
