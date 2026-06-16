import HTTPTypes
import Vapor

public struct ContentSecurityPolicy: Sendable {
    public var reportOnly: Bool
    public var allowsWasmUnsafeEval: Bool
    public var directives: [(String, [String])]

    public init(
        reportOnly: Bool = false,
        allowsWasmUnsafeEval: Bool = true,
        directives: [(String, [String])] = [
            ("default-src", ["'self'"]),
            ("base-uri", ["'self'"]),
            ("object-src", ["'none'"]),
            ("frame-ancestors", ["'none'"]),
            ("img-src", ["'self'", "data:"]),
            ("style-src", ["'self'", "'unsafe-inline'"]),
            ("connect-src", ["'self'"]),
            ("script-src", ["'self'"]),
        ]
    ) {
        self.reportOnly = reportOnly
        self.allowsWasmUnsafeEval = allowsWasmUnsafeEval
        self.directives = directives
    }

    public static let selfHosted = ContentSecurityPolicy()

    func headerName() -> HTTPField.Name {
        reportOnly ? .contentSecurityPolicyReportOnly : .contentSecurityPolicy
    }

    func headerValue(nonce: String?) -> String {
        directives.map { name, values in
            var currentValues = values
            if name == "script-src" {
                if let nonce {
                    currentValues.append("'nonce-\(nonce)'")
                }
                if allowsWasmUnsafeEval {
                    currentValues.append("'wasm-unsafe-eval'")
                }
            }
            return ([name] + currentValues).joined(separator: " ")
        }
        .joined(separator: "; ")
    }
}
