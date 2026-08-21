import XCTest

@testable import SwiftWebCLI

final class LifecycleCommandTerminationTests: XCTestCase {
    func testDevelopmentSignalIsGracefulTermination() {
        XCTAssertTrue(
            LifecycleCommand.isGracefulTermination(
                operation: .dev,
                terminationRequested: true
            )
        )
    }

    func testNonSignalAndFiniteOperationsRemainFailures() {
        XCTAssertFalse(
            LifecycleCommand.isGracefulTermination(
                operation: .dev,
                terminationRequested: false
            )
        )
        XCTAssertFalse(
            LifecycleCommand.isGracefulTermination(
                operation: .build,
                terminationRequested: true
            )
        )
        XCTAssertFalse(
            LifecycleCommand.isGracefulTermination(
                operation: .deploy,
                terminationRequested: true
            )
        )
    }
}
