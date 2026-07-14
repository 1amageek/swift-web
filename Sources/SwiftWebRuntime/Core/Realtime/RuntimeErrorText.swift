/// Error rendering for log messages; Embedded Swift has no reflection.
enum RuntimeErrorText {
    static func of(_ error: any Error) -> String {
        #if hasFeature(Embedded)
        "error"
        #else
        String(describing: error)
        #endif
    }
}
