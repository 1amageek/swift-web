#if os(macOS)
import Foundation
import WebKit

/// Loads a fixture document into an offscreen WKWebView and measures every
/// `[data-probe]` rectangle relative to the `#cr` fixture root.
@MainActor
final class WebKitMeasurement: NSObject, WKNavigationDelegate {
    enum MeasurementError: Error {
        case navigationFailed(String)
        case scriptFailed(String)
        case malformedResult
        case timedOut
    }

    private let webView: WKWebView
    private var navigationResult: Result<Void, MeasurementError>?

    override init() {
        let configuration = WKWebViewConfiguration()
        self.webView = WKWebView(
            frame: NSRect(x: 0, y: 0, width: Harness.rootWidth + 100, height: Harness.rootHeight + 100),
            configuration: configuration
        )
        super.init()
        webView.navigationDelegate = self
    }

    func measure(document: String) throws -> [String: ProbeRect] {
        navigationResult = nil
        webView.loadHTMLString(document, baseURL: nil)
        try pump(until: { self.navigationResult != nil })
        if case .failure(let error) = navigationResult {
            throw error
        }

        let script = """
        (() => {
          const root = document.getElementById('cr').getBoundingClientRect();
          const out = {};
          document.querySelectorAll('[data-probe]').forEach((element) => {
            const r = element.getBoundingClientRect();
            out[element.dataset.probe] = [r.x - root.x, r.y - root.y, r.width, r.height];
          });
          return JSON.stringify(out);
        })()
        """

        var scriptResult: Result<String, MeasurementError>?
        webView.evaluateJavaScript(script) { value, error in
            if let error {
                scriptResult = .failure(.scriptFailed(String(describing: error)))
            } else if let json = value as? String {
                scriptResult = .success(json)
            } else {
                scriptResult = .failure(.malformedResult)
            }
        }
        try pump(until: { scriptResult != nil })

        switch scriptResult {
        case .failure(let error):
            throw error
        case .none:
            throw MeasurementError.timedOut
        case .success(let json):
            guard
                let data = json.data(using: .utf8),
                let decoded = try? JSONDecoder().decode([String: [Double]].self, from: data)
            else {
                throw MeasurementError.malformedResult
            }
            var rects: [String: ProbeRect] = [:]
            for (probe, values) in decoded {
                guard values.count == 4 else {
                    throw MeasurementError.malformedResult
                }
                rects[probe] = ProbeRect(x: values[0], y: values[1], width: values[2], height: values[3])
            }
            return rects
        }
    }

    /// Pumps the main run loop until the condition holds or the deadline
    /// passes. The harness is a CLI, so WebKit's callbacks need the loop
    /// driven explicitly.
    private func pump(until condition: () -> Bool, timeout: TimeInterval = 10) throws {
        let deadline = Date().addingTimeInterval(timeout)
        while !condition() {
            guard Date() < deadline else {
                throw MeasurementError.timedOut
            }
            RunLoop.main.run(mode: .default, before: Date().addingTimeInterval(0.02))
        }
    }

    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        navigationResult = .success(())
    }

    func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: any Error) {
        navigationResult = .failure(.navigationFailed(String(describing: error)))
    }

    func webView(
        _ webView: WKWebView,
        didFailProvisionalNavigation navigation: WKNavigation!,
        withError error: any Error
    ) {
        navigationResult = .failure(.navigationFailed(String(describing: error)))
    }
}
#endif
