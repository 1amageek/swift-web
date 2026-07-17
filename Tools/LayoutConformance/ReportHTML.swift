#if os(macOS)
import Foundation

/// Renders the conformance run as a self-contained HTML page: each fixture
/// shows the live SwiftWebUI rendering (iframe srcdoc) with the SwiftUI
/// oracle rectangles overlaid, so a mismatch is visible as a dashed oracle
/// outline sitting apart from the painted web box.
enum ReportHTML {
    struct FixtureResult {
        let fixture: FixtureID
        let document: String
        let comparisons: [ProbeComparison]
    }

    static func render(_ results: [FixtureResult]) -> String {
        let total = results.flatMap(\.comparisons)
        let matched = total.filter(\.matches).count
        let sections = results.map(section(for:)).joined(separator: "\n")
        return """
        <!doctype html>
        <html>
        <head>
        <meta charset="utf-8">
        <title>SwiftWebUI Layout Conformance</title>
        <style>
        body { font: 14px -apple-system, sans-serif; margin: 24px; background: #f5f5f7; color: #1d1d1f; }
        h1 { font-size: 22px; }
        .summary { font-size: 16px; margin-bottom: 24px; }
        .fixture { background: #fff; border-radius: 10px; padding: 16px; margin-bottom: 24px; box-shadow: 0 1px 3px rgba(0,0,0,.12); }
        .fixture h2 { font-size: 15px; margin: 0 0 10px; font-family: ui-monospace, monospace; }
        .stage { position: relative; width: \(Int(Harness.rootWidth))px; height: \(Int(Harness.rootHeight))px; border: 1px solid #d2d2d7; }
        .stage iframe { width: 100%; height: 100%; border: 0; display: block; }
        .stage svg { position: absolute; inset: 0; pointer-events: none; }
        table { border-collapse: collapse; margin-top: 10px; font-family: ui-monospace, monospace; font-size: 12px; }
        th, td { padding: 3px 10px; border-bottom: 1px solid #e5e5ea; text-align: left; }
        .match { color: #248a3d; }
        .mismatch { color: #d70015; font-weight: 600; }
        .legend { font-size: 12px; color: #6e6e73; margin-top: 6px; }
        .ok { color: #248a3d; } .bad { color: #d70015; }
        </style>
        </head>
        <body>
        <h1>SwiftWebUI Layout Conformance</h1>
        <p class="summary">probes: \(total.count) · <span class="ok">match: \(matched)</span> · <span class="bad">mismatch: \(total.count - matched)</span> · tolerance: \(Harness.tolerance)px</p>
        <p class="legend">Painted boxes: SwiftWebUI rendering (WKWebView). Dashed blue outline: SwiftUI oracle geometry. Red fill flags a mismatched probe.</p>
        \(sections)
        </body>
        </html>
        """
    }

    private static func section(for result: FixtureResult) -> String {
        let matched = result.comparisons.filter(\.matches).count
        let overlays = result.comparisons.map { comparison -> String in
            var shapes: [String] = []
            if let oracle = comparison.oracle {
                shapes.append(
                    "<rect x=\"\(oracle.x)\" y=\"\(oracle.y)\" width=\"\(oracle.width)\" height=\"\(oracle.height)\" "
                        + "fill=\"\(comparison.matches ? "none" : "rgba(215,0,21,0.18)")\" "
                        + "stroke=\"#0a84ff\" stroke-dasharray=\"5 3\" stroke-width=\"1.5\"/>"
                )
            }
            if !comparison.matches, let web = comparison.web {
                shapes.append(
                    "<rect x=\"\(web.x)\" y=\"\(web.y)\" width=\"\(web.width)\" height=\"\(web.height)\" "
                        + "fill=\"none\" stroke=\"#d70015\" stroke-width=\"1.5\"/>"
                )
            }
            return shapes.joined()
        }
        .joined()

        let rows = result.comparisons.map { comparison -> String in
            let verdict = comparison.matches ? "match" : "MISMATCH"
            let cls = comparison.matches ? "match" : "mismatch"
            let delta = comparison.maxDelta.map { String(format: "%.1f", $0) } ?? "-"
            return "<tr><td>\(comparison.probe)</td><td>\(format(comparison.oracle))</td>"
                + "<td>\(format(comparison.web))</td><td>\(delta)</td><td class=\"\(cls)\">\(verdict)</td></tr>"
        }
        .joined()

        return """
        <div class="fixture">
        <h2>\(result.fixture.rawValue) — \(matched)/\(result.comparisons.count)</h2>
        <div class="stage">
        <iframe srcdoc="\(escapeAttribute(result.document))"></iframe>
        <svg width="\(Int(Harness.rootWidth))" height="\(Int(Harness.rootHeight))">\(overlays)</svg>
        </div>
        <table>
        <tr><th>probe</th><th>SwiftUI (x, y, w, h)</th><th>web (x, y, w, h)</th><th>Δmax</th><th>verdict</th></tr>
        \(rows)
        </table>
        </div>
        """
    }

    private static func format(_ rect: ProbeRect?) -> String {
        guard let rect else {
            return "(missing)"
        }
        return String(format: "(%.1f, %.1f, %.1f, %.1f)", rect.x, rect.y, rect.width, rect.height)
    }

    private static func escapeAttribute(_ html: String) -> String {
        html
            .replacingOccurrences(of: "&", with: "&amp;")
            .replacingOccurrences(of: "\"", with: "&quot;")
            .replacingOccurrences(of: "<", with: "&lt;")
            .replacingOccurrences(of: ">", with: "&gt;")
    }
}
#endif
