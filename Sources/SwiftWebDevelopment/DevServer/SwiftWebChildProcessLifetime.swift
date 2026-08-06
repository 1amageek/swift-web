import Foundation
import Synchronization

/// Keeps a command's complete descendant tree within the lifetime of its owner.
///
/// SwiftPM and SwiftBuild may place compiler subprocesses in process groups of
/// their own. A monitor therefore snapshots descendants by parent PID instead
/// of assuming that one process-group signal reaches the complete build tree.
package final class SwiftWebChildProcessLifetime: Sendable {
    private enum StartupError: Error, CustomStringConvertible {
        case monitorExited(processIdentifier: Int32, status: Int32, diagnostic: String)

        var description: String {
            switch self {
            case .monitorExited(let processIdentifier, let status, let diagnostic):
                let suffix = diagnostic.isEmpty ? "" : ": \(diagnostic)"
                return "process tree monitor for \(processIdentifier) exited with status \(status)\(suffix)"
            }
        }
    }

    private static let monitorScript = #"""
    set -u
    owner_pid="$1"
    command_pid="$2"
    grace_checks="$3"
    termination_requested=0
    known_pids=""

    append_pid() {
        candidate_pid="$1"
        case " $known_pids " in
            *" $candidate_pid "*) ;;
            *) known_pids="$known_pids $candidate_pid" ;;
        esac
    }

    snapshot_tree() {
        tree_root="$1"
        append_pid "$tree_root"
        for child_pid in $(/usr/bin/pgrep -P "$tree_root" 2>/dev/null || true); do
            snapshot_tree "$child_pid"
        done
    }

    request_termination() {
        termination_requested=1
    }
    trap request_termination HUP INT TERM USR1

    while [ "$termination_requested" -eq 0 ] \
        && kill -0 "$owner_pid" 2>/dev/null \
        && kill -0 "$command_pid" 2>/dev/null; do
        snapshot_tree "$command_pid"
        sleep 0.05 || true
    done

    if kill -0 "$command_pid" 2>/dev/null; then
        snapshot_tree "$command_pid"
    fi

    for target_pid in $known_pids; do
        kill -TERM "$target_pid" 2>/dev/null || true
    done

    check=0
    while [ "$check" -lt "$grace_checks" ]; do
        any_alive=0
        for target_pid in $known_pids; do
            if kill -0 "$target_pid" 2>/dev/null; then
                any_alive=1
                break
            fi
        done
        [ "$any_alive" -eq 0 ] && exit 0
        check=$((check + 1))
        sleep 0.1 || true
    done

    for target_pid in $known_pids; do
        kill -KILL "$target_pid" 2>/dev/null || true
    done
    """#

    private struct State {
        var monitor: Process?
    }

    private let state = Mutex(State())

    package init(
        commandProcessIdentifier: Int32,
        ownerProcessIdentifier: Int32 = ProcessInfo.processInfo.processIdentifier,
        terminationGracePeriod: TimeInterval
    ) throws {
        let monitor = Process()
        let diagnosticPipe = Pipe()
        monitor.executableURL = URL(fileURLWithPath: "/usr/bin/nohup")
        monitor.arguments = [
            "/bin/sh",
            "-c",
            Self.monitorScript,
            "swiftweb-child-process-lifetime",
            String(ownerProcessIdentifier),
            String(commandProcessIdentifier),
            String(Self.graceCheckCount(for: terminationGracePeriod)),
        ]
        monitor.standardInput = FileHandle.nullDevice
        monitor.standardOutput = FileHandle.nullDevice
        monitor.standardError = diagnosticPipe
        try monitor.run()
        Thread.sleep(forTimeInterval: 0.02)
        if !monitor.isRunning, kill(commandProcessIdentifier, 0) == 0 {
            let diagnosticData = try diagnosticPipe.fileHandleForReading.readToEnd() ?? Data()
            throw StartupError.monitorExited(
                processIdentifier: commandProcessIdentifier,
                status: monitor.terminationStatus,
                diagnostic: String(decoding: diagnosticData, as: UTF8.self)
                    .trimmingCharacters(in: .whitespacesAndNewlines)
            )
        }
        state.withLock { $0.monitor = monitor }
    }

    package func requestTermination() {
        let monitor = state.withLock { $0.monitor }
        guard let monitor, monitor.isRunning else {
            return
        }
        monitor.terminate()
    }

    package func waitUntilTerminated(timeout: TimeInterval) async -> Bool {
        let deadline = ContinuousClock().now.advanced(
            by: .milliseconds(Int64(max(0, timeout) * 1_000))
        )
        while isRunning, ContinuousClock().now < deadline {
            do {
                try await Task.sleep(for: .milliseconds(10))
            } catch {
                // Lifetime cleanup must finish even when the caller is cancelled.
            }
        }
        return !isRunning
    }

    package func clear() {
        state.withLock { $0.monitor = nil }
    }

    private var isRunning: Bool {
        state.withLock { $0.monitor?.isRunning == true }
    }

    private static func graceCheckCount(for gracePeriod: TimeInterval) -> Int {
        max(0, Int((gracePeriod * 10).rounded(.up)))
    }
}
