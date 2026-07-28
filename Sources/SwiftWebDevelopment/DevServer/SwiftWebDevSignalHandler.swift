import CSwiftWebSignals

enum SwiftWebDevSignalHandler {
    static func install() throws {
        let result = swift_web_install_termination_signal_handlers()
        guard result == 0 else {
            throw SwiftWebDevRuntimeError.signalHandlerInstallationFailed(code: result)
        }
    }

    static var shouldStop: Bool {
        swift_web_is_termination_requested()
    }
}
