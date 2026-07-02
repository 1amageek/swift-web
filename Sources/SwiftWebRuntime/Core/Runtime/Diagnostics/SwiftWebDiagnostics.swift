import Foundation

enum SwiftWebDiagnostics {
    #if DEBUG
    static let isEnabled = true
    #else
    static let isEnabled = false
    #endif

    static func formattedLines(for diagnostics: [RenderDiagnostic]) -> [String] {
        diagnostics.map { diagnostic in
            "SwiftWeb \(diagnostic.formattedMessage)"
        }
    }

    static func emit(_ diagnostics: [RenderDiagnostic]) {
        guard isEnabled else {
            return
        }

        guard !diagnostics.isEmpty else {
            return
        }

        for line in formattedLines(for: diagnostics) {
            FileHandle.standardError.write(Data((line + "\n").utf8))
        }
    }
}
