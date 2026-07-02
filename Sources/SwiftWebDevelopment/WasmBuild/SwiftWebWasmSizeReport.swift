import Foundation

package struct SwiftWebWasmSizeReport: Sendable, Codable, Equatable {
    package struct Section: Sendable, Codable, Equatable {
        package let id: UInt8
        package let name: String
        package let customName: String?
        package let offset: Int
        package let encodedBytes: Int
        package let payloadBytes: Int
        package let shareOfFile: Double
    }

    package struct Totals: Sendable, Codable, Equatable {
        package let customBytes: Int
        package let codeBytes: Int
        package let dataBytes: Int
        package let importBytes: Int
        package let exportBytes: Int
    }

    package let artifactPath: String
    package let originalBytes: Int
    package let finalBytes: Int
    package let gzipBytes: Int?
    package let brotliBytes: Int?
    package let transformations: [String]
    package let sections: [Section]
    package let totals: Totals

    package init(
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

    package var reportURL: URL {
        URL(fileURLWithPath: artifactPath + ".size.json")
    }

    package func write() throws {
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
