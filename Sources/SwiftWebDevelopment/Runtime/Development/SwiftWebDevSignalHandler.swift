import Darwin
import Synchronization

private let swiftWebDevTerminationRequested = Mutex(false)

private func handleSwiftWebDevTerminationSignal(_ signal: Int32) {
    swiftWebDevTerminationRequested.withLock { $0 = true }
}

enum SwiftWebDevSignalHandler {
    static func install() {
        swiftWebDevTerminationRequested.withLock { $0 = false }
        Darwin.signal(SIGINT, handleSwiftWebDevTerminationSignal)
        Darwin.signal(SIGTERM, handleSwiftWebDevTerminationSignal)
    }

    static var shouldStop: Bool {
        swiftWebDevTerminationRequested.withLock { $0 }
    }
}
