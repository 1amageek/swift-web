#if os(macOS)
import AppKit
import Foundation

// The harness needs an app context for AppKit/WebKit layout, but never
// shows UI.
_ = NSApplication.shared
NSApplication.shared.setActivationPolicy(.prohibited)

let results: [ReportHTML.FixtureResult] = MainActor.assumeIsolated {
    let webKit = WebKitMeasurement()
    var all: [ReportHTML.FixtureResult] = []
    for fixture in FixtureID.allCases {
        let oracle = OracleMeasurement.measure(fixture)
        let oracleImage = OracleMeasurement.snapshotPNGBase64(fixture)
        let document = WebFixtures.document(for: fixture)
        do {
            let web = try webKit.measure(document: document)
            all.append(
                ReportHTML.FixtureResult(
                    fixture: fixture,
                    document: document,
                    comparisons: ConformanceReport.compare(fixture: fixture, oracle: oracle, web: web),
                    oracleImage: oracleImage
                )
            )
        } catch {
            print("ERROR measuring \(fixture.rawValue) in WebKit: \(error)")
            all.append(
                ReportHTML.FixtureResult(
                    fixture: fixture,
                    document: document,
                    comparisons: ConformanceReport.compare(fixture: fixture, oracle: oracle, web: [:]),
                    oracleImage: oracleImage
                )
            )
        }
    }
    return all
}

ConformanceReport.printReport(results.flatMap(\.comparisons))

// The visual report: live SwiftWebUI renderings with the SwiftUI oracle
// rectangles overlaid, one card per fixture.
let reportPath = "Tools/LayoutConformance/report.html"
do {
    try ReportHTML.render(results).write(toFile: reportPath, atomically: true, encoding: .utf8)
    print("\nVisual report: \(reportPath)")
} catch {
    print("ERROR writing visual report: \(error)")
}
#else
fatalError("The layout conformance harness requires macOS (SwiftUI + WebKit).")
#endif
