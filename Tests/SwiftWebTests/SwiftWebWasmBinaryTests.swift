@testable import SwiftWebDevelopment
import Foundation
import Testing

@Suite
struct SwiftWebWasmBinaryTests {
    @Test
    func stripsDebugAndProducerCustomSections() throws {
        let module = wasmModule(
            sections: [
                customSection(name: "name", payload: [0x01]),
                section(id: 1, payload: [0x60, 0x00, 0x00]),
                customSection(name: ".debug_info", payload: [0x02]),
                customSection(name: "target_features", payload: [0x03]),
                customSection(name: "producers", payload: [0x04]),
            ]
        )

        let stripped = try SwiftWebWasmBinary(data: module).strippedData()
        let binary = try SwiftWebWasmBinary(data: stripped)
        let names = binary.sections.map(\.displayName)

        #expect(names == ["type", "custom:target_features"])
    }

    @Test
    func writesSizeReportWithSectionAttribution() throws {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("SwiftWebWasmBinaryTests-\(UUID().uuidString)", isDirectory: true)
        defer {
            do {
                try FileManager.default.removeItem(at: root)
            } catch {}
        }
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        let artifactURL = root.appendingPathComponent("runtime.wasm")
        let data = wasmModule(
            sections: [
                customSection(name: "target_features", payload: [0x01]),
                section(id: 10, payload: [0x01, 0x02, 0x03]),
                section(id: 11, payload: [0x04, 0x05]),
            ]
        )
        try data.write(to: artifactURL)

        let report = try SwiftWebWasmSizeReport(
            artifactURL: artifactURL,
            originalBytes: data.count,
            finalData: data,
            gzipBytes: 12,
            brotliBytes: 10,
            transformations: ["strip-custom-sections"]
        )
        try report.write()

        #expect(report.finalBytes == data.count)
        #expect(report.totals.codeBytes > 0)
        #expect(report.totals.dataBytes > 0)
        #expect(report.sections.map(\.name).contains("custom:target_features"))
        #expect(FileManager.default.fileExists(atPath: report.reportURL.path))
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
