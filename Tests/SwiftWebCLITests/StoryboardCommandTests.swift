import Foundation
import XCTest

@testable import SwiftWebCLI

final class StoryboardCommandTests: XCTestCase {
    func testSelectionAndLifecycleFailures() async throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        let target = root.appendingPathComponent("custom preview")
        try FileManager.default.createDirectory(at: target, withIntermediateDirectories: true)
        defer { do { try FileManager.default.removeItem(at: root) } catch { XCTFail("\(error)") } }
        let manifest = root.appendingPathComponent("sweb.json")
        func configure(_ value: String) throws {
            try value.write(to: manifest, atomically: true, encoding: .utf8)
        }
        let command = try StoryboardCommand.parse(ArgumentParser(arguments: [
            "--package-path", root.path, "--environment", "preview", "--host", "127.0.0.2", "--port", "4567",
        ]))
        XCTAssertThrowsError(try command.resolvedLifecycleCommand())
        for invalid in ["{", "{}", #"{"schemaVersion":2,"storyboard":{"packagePath":"custom preview"}}"#,
                        #"{"schemaVersion":3}"#, #"{"schemaVersion":3,"storyboard":{"packagePath":""}}"#,
                        #"{"schemaVersion":3,"storyboard":{"packagePath":"/tmp"}}"#] {
            try configure(invalid)
            XCTAssertThrowsError(try command.resolvedLifecycleCommand(), invalid)
        }
        try configure(#"{"schemaVersion":3,"storyboard":{"packagePath":"custom preview"}}"#)
        XCTAssertThrowsError(try command.resolvedLifecycleCommand())
        try "".write(to: target.appendingPathComponent("Package.swift"), atomically: true, encoding: .utf8)
        XCTAssertThrowsError(try command.resolvedLifecycleCommand())
        try "{}".write(to: target.appendingPathComponent("sweb.json"), atomically: true, encoding: .utf8)
        let resolved = try command.resolvedLifecycleCommand()
        XCTAssertEqual(resolved.packageDirectory.path, target.path)
        XCTAssertEqual(resolved.operation, .dev)
        XCTAssertEqual(resolved.environment, "preview")
        XCTAssertEqual(resolved.host, "127.0.0.2")
        XCTAssertEqual(resolved.port, 4567)
        do {
            try await command.run()
            XCTFail("The selected application's invalid manifest must fail through the real lifecycle")
        } catch is DecodingError {
            // The generic project resolver owns target manifest validation.
        }
        XCTAssertFalse(FileManager.default.fileExists(atPath: root.appendingPathComponent(".swiftweb").path))
        XCTAssertFalse(FileManager.default.fileExists(atPath: target.appendingPathComponent("Sources").path))
    }

    func testOperationsReuseLifecycleOptions() throws {
        let build = try StoryboardCommand.parse(ArgumentParser(arguments: ["build", "--runtime", "embedded"]))
        XCTAssertEqual(build.lifecycle.operation, .build)
        XCTAssertEqual(build.lifecycle.wasmRuntimeProfile, .embedded)
        XCTAssertEqual(try StoryboardCommand.parse(ArgumentParser(arguments: ["prepare"])).lifecycle.operation, .prepare)
        for arguments in [["deploy"], ["--production"], ["--no-run"], ["--output", "preview"], ["dev", "--runtime", "embedded"]] {
            XCTAssertThrowsError(try StoryboardCommand.parse(ArgumentParser(arguments: arguments)))
        }
    }
}
