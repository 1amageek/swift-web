@testable import SwiftWebDevelopment
import Foundation
import Testing

@Suite
struct SwiftWebWasmArtifactProcessorTests {
    @Test
    func productionWritesCompressedSidecarsAndSizeReport() throws {
        let root = try temporaryDirectory()
        defer {
            do {
                try FileManager.default.removeItem(at: root)
            } catch {}
        }
        let toolsDirectory = root.appendingPathComponent("tools", isDirectory: true)
        try FileManager.default.createDirectory(
            at: toolsDirectory,
            withIntermediateDirectories: true
        )
        try writeFakeTool(
            """
            #!/bin/sh
            input="$2"
            output="$4"
            /bin/cp "$input" "$output"
            """,
            named: "wasm-opt",
            in: toolsDirectory
        )
        try writeFakeTool(
            """
            #!/bin/sh
            input="$4"
            /bin/cp "$input" "$input.gz"
            """,
            named: "gzip",
            in: toolsDirectory
        )
        try writeFakeTool(
            """
            #!/bin/sh
            output=""
            input=""
            while [ "$#" -gt 0 ]; do
              case "$1" in
                -o)
                  shift
                  output="$1"
                  ;;
                -*)
                  ;;
                *)
                  input="$1"
                  ;;
              esac
              shift
            done
            /bin/cp "$input" "$output"
            """,
            named: "brotli",
            in: toolsDirectory
        )
        let artifactURL = root.appendingPathComponent("runtime.wasm")
        try wasmModule(
            sections: [
                customSection(name: "name", payload: [0x01]),
                section(id: 10, payload: [0x02, 0x03]),
            ]
        )
        .write(to: artifactURL)

        let processor = SwiftWebWasmArtifactProcessor(
            options: .production(environment: [:]),
            environment: ["PATH": toolsDirectory.path]
        )
        let result = try processor.process(fileURL: artifactURL)

        #expect(result.transformations.contains("strip-custom-sections"))
        #expect(result.transformations.contains("wasm-opt -Oz"))
        #expect(result.gzipBytes != nil)
        #expect(result.brotliBytes != nil)
        #expect(FileManager.default.fileExists(atPath: artifactURL.path + ".gz"))
        #expect(FileManager.default.fileExists(atPath: artifactURL.path + ".br"))
        #expect(FileManager.default.fileExists(atPath: artifactURL.path + ".size.json"))
        #expect(FileManager.default.fileExists(
            atPath: SwiftWebWasmCompressionCache.cacheURL(for: artifactURL).path
        ))
    }

    @Test
    func productionReusesCompressedSidecarsWhenContentHashMatches() throws {
        let root = try temporaryDirectory()
        defer {
            do {
                try FileManager.default.removeItem(at: root)
            } catch {}
        }
        let toolsDirectory = root.appendingPathComponent("tools", isDirectory: true)
        try FileManager.default.createDirectory(at: toolsDirectory, withIntermediateDirectories: true)
        let logURL = root.appendingPathComponent("compression.log")
        try writeFakeTool(
            """
            #!/bin/sh
            echo gzip >> \(shellQuoted(logURL.path))
            input="$4"
            /bin/cp "$input" "$input.gz"
            """,
            named: "gzip",
            in: toolsDirectory
        )
        try writeFakeTool(
            """
            #!/bin/sh
            echo brotli >> \(shellQuoted(logURL.path))
            output=""
            input=""
            while [ "$#" -gt 0 ]; do
              case "$1" in
                -o)
                  shift
                  output="$1"
                  ;;
                -*)
                  ;;
                *)
                  input="$1"
                  ;;
              esac
              shift
            done
            /bin/cp "$input" "$output"
            """,
            named: "brotli",
            in: toolsDirectory
        )

        let artifactURL = root.appendingPathComponent("runtime.wasm")
        try wasmModule(sections: [section(id: 10, payload: [0x01, 0x02])])
            .write(to: artifactURL)
        let processor = SwiftWebWasmArtifactProcessor(
            options: .production(environment: ["SWIFTWEB_WASM_OPTIMIZE": "0"]),
            environment: ["PATH": toolsDirectory.path]
        )

        _ = try processor.process(fileURL: artifactURL)
        let firstLog = try String(contentsOf: logURL, encoding: .utf8)
        #expect(firstLog.split(whereSeparator: \.isNewline).count == 2)

        _ = try processor.process(fileURL: artifactURL)
        let secondLog = try String(contentsOf: logURL, encoding: .utf8)
        #expect(secondLog == firstLog)

        try wasmModule(sections: [section(id: 10, payload: [0x03, 0x04])])
            .write(to: artifactURL)
        _ = try processor.process(fileURL: artifactURL)
        let thirdLog = try String(contentsOf: logURL, encoding: .utf8)
        #expect(thirdLog.split(whereSeparator: \.isNewline).count == 4)
    }

    @Test
    func developmentRemovesCompressedSidecars() throws {
        let root = try temporaryDirectory()
        defer {
            do {
                try FileManager.default.removeItem(at: root)
            } catch {}
        }
        let artifactURL = root.appendingPathComponent("runtime.wasm")
        try wasmModule(sections: [section(id: 10, payload: [0x01])]).write(to: artifactURL)
        try Data("stale".utf8).write(to: URL(fileURLWithPath: artifactURL.path + ".gz"))
        try Data("stale".utf8).write(to: URL(fileURLWithPath: artifactURL.path + ".br"))
        try Data("stale".utf8).write(to: SwiftWebWasmCompressionCache.cacheURL(for: artifactURL))

        let processor = SwiftWebWasmArtifactProcessor(
            options: .development(environment: [:]),
            environment: ["PATH": ""]
        )
        let result = try processor.process(fileURL: artifactURL)

        #expect(result.gzipBytes == nil)
        #expect(result.brotliBytes == nil)
        #expect(!FileManager.default.fileExists(atPath: artifactURL.path + ".gz"))
        #expect(!FileManager.default.fileExists(atPath: artifactURL.path + ".br"))
        #expect(!FileManager.default.fileExists(
            atPath: SwiftWebWasmCompressionCache.cacheURL(for: artifactURL).path
        ))
        #expect(FileManager.default.fileExists(atPath: artifactURL.path + ".size.json"))
    }

    @Test
    func productionRegeneratesExistingGzipSidecar() throws {
        let root = try temporaryDirectory()
        defer {
            do {
                try FileManager.default.removeItem(at: root)
            } catch {}
        }
        let toolsDirectory = root.appendingPathComponent("tools", isDirectory: true)
        try FileManager.default.createDirectory(at: toolsDirectory, withIntermediateDirectories: true)
        try writeFakeTool(
            """
            #!/bin/sh
            input="$4"
            /bin/cp "$input" "$input.gz"
            """,
            named: "gzip",
            in: toolsDirectory
        )

        let artifactURL = root.appendingPathComponent("runtime.wasm")
        let artifactData = wasmModule(sections: [section(id: 10, payload: [0x01, 0x02])])
        try artifactData.write(to: artifactURL)
        try Data("stale".utf8).write(to: URL(fileURLWithPath: artifactURL.path + ".gz"))

        let processor = SwiftWebWasmArtifactProcessor(
            options: .production(environment: ["SWIFTWEB_WASM_OPTIMIZE": "0"]),
            environment: ["PATH": toolsDirectory.path]
        )
        let result = try processor.process(fileURL: artifactURL)
        let gzipData = try Data(contentsOf: URL(fileURLWithPath: artifactURL.path + ".gz"))

        #expect(result.gzipBytes == artifactData.count)
        #expect(gzipData == artifactData)
    }

    private func temporaryDirectory() throws -> URL {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("SwiftWebWasmArtifactProcessorTests-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        return url
    }

    private func writeFakeTool(_ contents: String, named name: String, in directory: URL) throws {
        let url = directory.appendingPathComponent(name)
        try contents.write(to: url, atomically: true, encoding: .utf8)
        try FileManager.default.setAttributes(
            [.posixPermissions: 0o755],
            ofItemAtPath: url.path
        )
    }

    private func shellQuoted(_ value: String) -> String {
        "'\(value.replacingOccurrences(of: "'", with: "'\\''"))'"
    }

    private func wasmModule(sections: [Data]) -> Data {
        var data = Data(SwiftWebWasmBinary.magic)
        for section in sections {
            data.append(section)
        }
        return data
    }

    private func section(id: UInt8, payload: [UInt8]) -> Data {
        var data = Data([id])
        data.append(varUInt(UInt32(payload.count)))
        data.append(contentsOf: payload)
        return data
    }

    private func customSection(name: String, payload: [UInt8]) -> Data {
        var customPayload = Data()
        let nameBytes = Array(name.utf8)
        customPayload.append(varUInt(UInt32(nameBytes.count)))
        customPayload.append(contentsOf: nameBytes)
        customPayload.append(contentsOf: payload)
        return section(id: 0, payload: Array(customPayload))
    }

    private func varUInt(_ value: UInt32) -> Data {
        var value = value
        var bytes: [UInt8] = []
        repeat {
            var byte = UInt8(value & 0x7f)
            value >>= 7
            if value != 0 {
                byte |= 0x80
            }
            bytes.append(byte)
        } while value != 0
        return Data(bytes)
    }
}
