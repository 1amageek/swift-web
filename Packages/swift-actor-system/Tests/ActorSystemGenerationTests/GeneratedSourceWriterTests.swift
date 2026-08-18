@testable import ActorSystemGeneration
import Foundation
import Testing

@Suite
struct GeneratedSourceWriterTests {
    @Test
    func generatedDirectoryRejectsFilesOutsideItsManifest() throws {
        let fixture = try GeneratedWriterFixture()
        defer { fixture.remove() }
        _ = try ActorGeneratedSourceWriter.write(
            [GeneratedActorSource(relativePath: "Actor.generated.swift", contents: "let value = 1")],
            to: fixture.output
        )
        try "user-owned".write(
            to: fixture.output.appendingPathComponent("Manual.swift"),
            atomically: true,
            encoding: .utf8
        )

        #expect(throws: ActorGenerationError.self) {
            _ = try ActorGeneratedSourceWriter.write(
                [GeneratedActorSource(relativePath: "Actor.generated.swift", contents: "let value = 2")],
                to: fixture.output
            )
        }
    }

    @Test
    func generatedDirectoryRejectsModifiedOwnedFiles() throws {
        let fixture = try GeneratedWriterFixture()
        defer { fixture.remove() }
        let relativePath = "Actor.generated.swift"
        _ = try ActorGeneratedSourceWriter.write(
            [GeneratedActorSource(relativePath: relativePath, contents: "let value = 1")],
            to: fixture.output
        )
        try "let value = 99".write(
            to: fixture.output.appendingPathComponent(relativePath),
            atomically: true,
            encoding: .utf8
        )

        #expect(throws: ActorGenerationError.self) {
            _ = try ActorGeneratedSourceWriter.write(
                [GeneratedActorSource(relativePath: relativePath, contents: "let value = 2")],
                to: fixture.output
            )
        }
    }

    @Test
    func schemaCommitFailureRestoresThePreviousGeneratedSet() throws {
        let fixture = try GeneratedWriterFixture()
        defer { fixture.remove() }
        let relativePath = "Actor.generated.swift"
        _ = try ActorGeneratedSourceWriter.write(
            [GeneratedActorSource(relativePath: relativePath, contents: "let value = 1")],
            to: fixture.output
        )

        #expect(throws: WriterFixtureError.self) {
            _ = try ActorGeneratedSourceWriter.write(
                [GeneratedActorSource(relativePath: relativePath, contents: "let value = 2")],
                to: fixture.output,
                committing: { throw WriterFixtureError.commitFailed }
            )
        }
        let restored = try String(
            contentsOf: fixture.output.appendingPathComponent(relativePath),
            encoding: .utf8
        )
        #expect(restored == "let value = 1")
    }
}

private enum WriterFixtureError: Error {
    case commitFailed
}

private struct GeneratedWriterFixture {
    let root: URL
    let output: URL

    init() throws {
        root = FileManager.default.temporaryDirectory.appendingPathComponent(
            "actor-writer-test-\(UUID().uuidString)",
            isDirectory: true
        )
        output = root.appendingPathComponent("Generated", isDirectory: true)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
    }

    func remove() {
        do {
            try FileManager.default.removeItem(at: root)
        } catch {
            // Test cleanup does not change the assertion result.
        }
    }
}
