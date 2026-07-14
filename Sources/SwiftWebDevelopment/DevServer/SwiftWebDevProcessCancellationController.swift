import Foundation
import Synchronization

/// Bridges structured task cancellation to a Foundation child process.
package final class SwiftWebDevProcessCancellationController: Sendable {
    private let process = Mutex<Process?>(nil)

    package init() {}

    package func install(_ process: Process) {
        self.process.withLock { $0 = process }
    }

    package func clear() {
        process.withLock { $0 = nil }
    }

    package func cancel() {
        let runningProcess = process.withLock { $0 }
        guard let runningProcess, runningProcess.isRunning else {
            return
        }
        runningProcess.terminate()
    }
}
