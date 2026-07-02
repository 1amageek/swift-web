import Foundation

package struct SwiftWebWasmBinary: Sendable, Equatable {
    package struct Section: Sendable, Equatable {
        package let id: UInt8
        package let offset: Int
        package let headerBytes: Int
        package let payloadOffset: Int
        package let payloadBytes: Int
        package let customName: String?

        package var encodedBytes: Int {
            headerBytes + payloadBytes
        }

        package var endOffset: Int {
            payloadOffset + payloadBytes
        }

        package var displayName: String {
            if let customName {
                return "custom:\(customName)"
            }
            return Self.standardName(for: id)
        }

        package static func standardName(for id: UInt8) -> String {
            switch id {
            case 0: "custom"
            case 1: "type"
            case 2: "import"
            case 3: "function"
            case 4: "table"
            case 5: "memory"
            case 6: "global"
            case 7: "export"
            case 8: "start"
            case 9: "element"
            case 10: "code"
            case 11: "data"
            case 12: "data-count"
            case 13: "tag"
            default: "section-\(id)"
            }
        }
    }

    package enum ParseError: Error, Equatable, CustomStringConvertible {
        case invalidMagic
        case truncatedSectionHeader(offset: Int)
        case malformedVarUInt(offset: Int)
        case sectionOutOfBounds(offset: Int, length: Int, fileBytes: Int)
        case malformedCustomSectionName(offset: Int)

        package var description: String {
            switch self {
            case .invalidMagic:
                "invalid WebAssembly module header"
            case .truncatedSectionHeader(let offset):
                "truncated WebAssembly section header at byte \(offset)"
            case .malformedVarUInt(let offset):
                "malformed WebAssembly varuint at byte \(offset)"
            case .sectionOutOfBounds(let offset, let length, let fileBytes):
                "WebAssembly section at byte \(offset) has length \(length), exceeding file size \(fileBytes)"
            case .malformedCustomSectionName(let offset):
                "malformed WebAssembly custom section name at byte \(offset)"
            }
        }
    }

    package static let magic: [UInt8] = [0x00, 0x61, 0x73, 0x6d, 0x01, 0x00, 0x00, 0x00]
    package static let defaultRemovedCustomSectionNames: Set<String> = [
        "name",
        "producers",
        "sourceMappingURL",
    ]

    package let data: Data
    package let sections: [Section]

    package init(data: Data) throws {
        self.data = data
        self.sections = try Self.parseSections(in: [UInt8](data))
    }

    package func strippedData(
        removingCustomSectionNames names: Set<String> = defaultRemovedCustomSectionNames
    ) throws -> Data {
        var output = Data()
        let bytes = [UInt8](data)
        output.append(contentsOf: bytes[0..<Self.magic.count])

        for section in sections {
            if shouldRemove(section: section, names: names) {
                continue
            }
            output.append(contentsOf: bytes[section.offset..<section.endOffset])
        }

        return output
    }

    private func shouldRemove(section: Section, names: Set<String>) -> Bool {
        guard section.id == 0, let customName = section.customName else {
            return false
        }
        return names.contains(customName) || customName.hasPrefix(".debug_")
    }

    private static func parseSections(in bytes: [UInt8]) throws -> [Section] {
        guard bytes.count >= magic.count, Array(bytes[0..<magic.count]) == magic else {
            throw ParseError.invalidMagic
        }

        var sections: [Section] = []
        var offset = magic.count
        while offset < bytes.count {
            let sectionOffset = offset
            guard offset < bytes.count else {
                throw ParseError.truncatedSectionHeader(offset: sectionOffset)
            }
            let id = bytes[offset]
            offset += 1
            let lengthOffset = offset
            let payloadLength = Int(try readVarUInt32(from: bytes, index: &offset, limit: bytes.count))
            let headerBytes = offset - sectionOffset
            let payloadOffset = offset
            let payloadEnd = payloadOffset + payloadLength
            guard payloadEnd <= bytes.count else {
                throw ParseError.sectionOutOfBounds(
                    offset: sectionOffset,
                    length: payloadLength,
                    fileBytes: bytes.count
                )
            }

            let customName: String?
            if id == 0 {
                customName = try readCustomSectionName(
                    from: bytes,
                    payloadOffset: payloadOffset,
                    payloadEnd: payloadEnd,
                    lengthOffset: lengthOffset
                )
            } else {
                customName = nil
            }

            sections.append(
                Section(
                    id: id,
                    offset: sectionOffset,
                    headerBytes: headerBytes,
                    payloadOffset: payloadOffset,
                    payloadBytes: payloadLength,
                    customName: customName
                )
            )
            offset = payloadEnd
        }

        return sections
    }

    private static func readCustomSectionName(
        from bytes: [UInt8],
        payloadOffset: Int,
        payloadEnd: Int,
        lengthOffset: Int
    ) throws -> String? {
        guard payloadOffset < payloadEnd else {
            return nil
        }

        var nameOffset = payloadOffset
        let nameLength = Int(try readVarUInt32(from: bytes, index: &nameOffset, limit: payloadEnd))
        let nameEnd = nameOffset + nameLength
        guard nameEnd <= payloadEnd else {
            throw ParseError.malformedCustomSectionName(offset: lengthOffset)
        }
        guard let name = String(bytes: bytes[nameOffset..<nameEnd], encoding: .utf8) else {
            throw ParseError.malformedCustomSectionName(offset: lengthOffset)
        }
        return name
    }

    private static func readVarUInt32(from bytes: [UInt8], index: inout Int, limit: Int) throws -> UInt32 {
        let start = index
        var result: UInt32 = 0
        var shift: UInt32 = 0

        while index < limit {
            let byte = bytes[index]
            index += 1
            result |= UInt32(byte & 0x7f) << shift
            if byte & 0x80 == 0 {
                return result
            }
            shift += 7
            if shift >= 35 {
                throw ParseError.malformedVarUInt(offset: start)
            }
        }

        throw ParseError.malformedVarUInt(offset: start)
    }
}
