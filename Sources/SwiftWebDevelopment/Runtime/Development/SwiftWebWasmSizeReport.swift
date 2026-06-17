import Foundation

struct SwiftWebWasmSizeReport: Sendable, Codable, Equatable {
    struct Section: Sendable, Codable, Equatable {
        let id: UInt8
        let name: String
        let customName: String?
        let offset: Int
        let encodedBytes: Int
        let payloadBytes: Int
        let shareOfFile: Double
    }

    struct Totals: Sendable, Codable, Equatable {
        let customBytes: Int
        let codeBytes: Int
        let dataBytes: Int
        let importBytes: Int
        let exportBytes: Int
    }

    let artifactPath: String
    let originalBytes: Int
    let finalBytes: Int
    let gzipBytes: Int?
    let brotliBytes: Int?
    let transformations: [String]
    let sections: [Section]
    let totals: Totals

    init(
        artifactURL: URL,
        originalBytes: Int,
        finalData: Data,
        gzipBytes: Int?,
        brotliBytes: Int?,
        transformations: [String]
    ) throws {
        let binary = try SwiftWebWasmBinary(data: finalData)
        let finalBytes = finalData.count
        self.artifactPath = artifactURL.path
        self.originalBytes = originalBytes
        self.finalBytes = finalBytes
        self.gzipBytes = gzipBytes
        self.brotliBytes = brotliBytes
        self.transformations = transformations
        self.sections = binary.sections.map { section in
            Section(
                id: section.id,
                name: section.displayName,
                customName: section.customName,
                offset: section.offset,
                encodedBytes: section.encodedBytes,
                payloadBytes: section.payloadBytes,
                shareOfFile: finalBytes == 0 ? 0 : Double(section.encodedBytes) / Double(finalBytes)
            )
        }
        self.totals = Totals(
            customBytes: Self.totalEncodedBytes(for: 0, in: binary.sections),
            codeBytes: Self.totalEncodedBytes(for: 10, in: binary.sections),
            dataBytes: Self.totalEncodedBytes(for: 11, in: binary.sections),
            importBytes: Self.totalEncodedBytes(for: 2, in: binary.sections),
            exportBytes: Self.totalEncodedBytes(for: 7, in: binary.sections)
        )
    }

    var reportURL: URL {
        URL(fileURLWithPath: artifactPath + ".size.json")
    }

    func write() throws {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        let data = try encoder.encode(self)
        try data.write(to: reportURL, options: [.atomic])
    }

    private static func totalEncodedBytes(
        for id: UInt8,
        in sections: [SwiftWebWasmBinary.Section]
    ) -> Int {
        sections
            .filter { $0.id == id }
            .reduce(0) { partial, section in
                partial + section.encodedBytes
            }
    }
}
