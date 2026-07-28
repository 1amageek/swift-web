import Foundation
import Logging

#if canImport(Darwin)
import Darwin
#elseif canImport(Glibc)
import Glibc
#endif

package enum SwiftWebDevParentProcessMonitor {
    package static let parentPIDEnvironmentKey = "SWIFT_WEB_DEV_PARENT_PID"
    private static let pollIntervalNanoseconds: UInt64 = 500_000_000

    package static func startIfNeeded(logger: Logger) -> Task<Void, Never>? {
        guard let parentPID = parentPID(from: ProcessInfo.processInfo.environment) else {
            return nil
        }

        return Task.detached(priority: .utility) {
            await monitor(parentPID: parentPID, logger: logger)
        }
    }

    package static func parentPID(from environment: [String: String]) -> pid_t? {
        guard let rawValue = environment[parentPIDEnvironmentKey],
              let value = Int32(rawValue),
              value > 1
        else {
            return nil
        }
        return pid_t(value)
    }

    package static func shouldExit(parentPID: pid_t, currentParentPID: pid_t, parentExists: Bool) -> Bool {
        currentParentPID != parentPID || !parentExists
    }

    private static func monitor(parentPID: pid_t, logger: Logger) async {
        while !Task.isCancelled {
            let currentParentPID = currentParentProcessID()
            if shouldExit(
                parentPID: parentPID,
                currentParentPID: currentParentPID,
                parentExists: processExists(parentPID)
            ) {
                logger.warning(
                    "SwiftWeb dev parent process disappeared. Exiting child server.",
                    metadata: [
                        "parentPID": .string(String(parentPID)),
                        "currentParentPID": .string(String(currentParentPID)),
                    ]
                )
                exitSuccessfully()
            }

            do {
                try await Task.sleep(nanoseconds: pollIntervalNanoseconds)
            } catch {
                return
            }
        }
    }

    private static func currentParentProcessID() -> pid_t {
        #if canImport(Darwin)
        Darwin.getppid()
        #elseif canImport(Glibc)
        Glibc.getppid()
        #endif
    }

    private static func exitSuccessfully() -> Never {
        #if canImport(Darwin)
        Darwin.exit(EXIT_SUCCESS)
        #elseif canImport(Glibc)
        Glibc.exit(EXIT_SUCCESS)
        #endif
    }

    private static func processExists(_ pid: pid_t) -> Bool {
        #if canImport(Darwin)
        let result = Darwin.kill(pid, 0)
        #elseif canImport(Glibc)
        let result = Glibc.kill(pid, 0)
        #endif
        if result == 0 {
            return true
        }
        return errno == EPERM
    }
}
