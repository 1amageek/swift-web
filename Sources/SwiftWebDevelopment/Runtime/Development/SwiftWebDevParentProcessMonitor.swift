import Darwin
import Foundation
import Logging

enum SwiftWebDevParentProcessMonitor {
    static let parentPIDEnvironmentKey = "SWIFT_WEB_DEV_PARENT_PID"
    private static let pollIntervalNanoseconds: UInt64 = 500_000_000

    static func startIfNeeded(logger: Logger) -> Task<Void, Never>? {
        guard let parentPID = parentPID(from: ProcessInfo.processInfo.environment) else {
            return nil
        }

        return Task.detached(priority: .utility) {
            await monitor(parentPID: parentPID, logger: logger)
        }
    }

    static func parentPID(from environment: [String: String]) -> pid_t? {
        guard let rawValue = environment[parentPIDEnvironmentKey],
              let value = Int32(rawValue),
              value > 1
        else {
            return nil
        }
        return pid_t(value)
    }

    static func shouldExit(parentPID: pid_t, currentParentPID: pid_t, parentExists: Bool) -> Bool {
        currentParentPID != parentPID || !parentExists
    }

    private static func monitor(parentPID: pid_t, logger: Logger) async {
        while !Task.isCancelled {
            if shouldExit(
                parentPID: parentPID,
                currentParentPID: Darwin.getppid(),
                parentExists: processExists(parentPID)
            ) {
                logger.warning(
                    "SwiftWeb dev parent process disappeared. Exiting child server.",
                    metadata: [
                        "parentPID": .string(String(parentPID)),
                        "currentParentPID": .string(String(Darwin.getppid())),
                    ]
                )
                Darwin.exit(EXIT_SUCCESS)
            }

            do {
                try await Task.sleep(nanoseconds: pollIntervalNanoseconds)
            } catch {
                return
            }
        }
    }

    private static func processExists(_ pid: pid_t) -> Bool {
        if Darwin.kill(pid, 0) == 0 {
            return true
        }
        return errno == EPERM
    }
}
