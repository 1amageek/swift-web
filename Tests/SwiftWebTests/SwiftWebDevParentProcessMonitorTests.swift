@testable import SwiftWebDevelopment
import Testing

@Suite
struct SwiftWebDevParentProcessMonitorTests {
    @Test
    func parsesParentPIDFromEnvironment() {
        let pid = SwiftWebDevParentProcessMonitor.parentPID(
            from: [
                SwiftWebDevParentProcessMonitor.parentPIDEnvironmentKey: "12345",
            ]
        )

        #expect(pid == 12345)
    }

    @Test
    func ignoresMissingOrInvalidParentPID() {
        #expect(SwiftWebDevParentProcessMonitor.parentPID(from: [:]) == nil)
        #expect(SwiftWebDevParentProcessMonitor.parentPID(from: [
            SwiftWebDevParentProcessMonitor.parentPIDEnvironmentKey: "not-a-pid",
        ]) == nil)
        #expect(SwiftWebDevParentProcessMonitor.parentPID(from: [
            SwiftWebDevParentProcessMonitor.parentPIDEnvironmentKey: "1",
        ]) == nil)
    }

    @Test
    func exitsWhenParentChangesOrDisappears() {
        #expect(!SwiftWebDevParentProcessMonitor.shouldExit(
            parentPID: 12345,
            currentParentPID: 12345,
            parentExists: true
        ))
        #expect(SwiftWebDevParentProcessMonitor.shouldExit(
            parentPID: 12345,
            currentParentPID: 1,
            parentExists: true
        ))
        #expect(SwiftWebDevParentProcessMonitor.shouldExit(
            parentPID: 12345,
            currentParentPID: 12345,
            parentExists: false
        ))
    }
}
