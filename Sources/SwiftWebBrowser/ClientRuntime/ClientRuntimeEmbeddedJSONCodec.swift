import ActorSystemCore
import SwiftHTML
import SwiftWebActors

private indirect enum ClientRuntimeEmbeddedJSONValue {
    case object([String: ClientRuntimeEmbeddedJSONValue])
    case array([ClientRuntimeEmbeddedJSONValue])
    case string(String)
    case number(String)
    case boolean(Bool)
    case null
}

private struct ClientRuntimeEmbeddedJSONParser {
    private let bytes: [UInt8]
    private var index = 0
    private let maximumDepth = 256

    init(_ bytes: [UInt8]) {
        self.bytes = bytes
    }

    mutating func parse() throws -> ClientRuntimeEmbeddedJSONValue {
        skipWhitespace()
        let value = try parseValue(depth: 0)
        skipWhitespace()
        guard index == bytes.count else {
            throw ClientRuntimeJSONCodecError.malformedJSON(offset: index)
        }
        return value
    }

    private mutating func parseValue(
        depth: Int
    ) throws -> ClientRuntimeEmbeddedJSONValue {
        guard depth <= maximumDepth else {
            throw ClientRuntimeJSONCodecError.nestingLimitExceeded(maximumDepth)
        }
        guard index < bytes.count else {
            throw ClientRuntimeJSONCodecError.malformedJSON(offset: index)
        }
        switch bytes[index] {
        case 0x7B:
            return try parseObject(depth: depth + 1)
        case 0x5B:
            return try parseArray(depth: depth + 1)
        case 0x22:
            return .string(try parseString())
        case 0x74:
            try consumeLiteral([0x74, 0x72, 0x75, 0x65])
            return .boolean(true)
        case 0x66:
            try consumeLiteral([0x66, 0x61, 0x6C, 0x73, 0x65])
            return .boolean(false)
        case 0x6E:
            try consumeLiteral([0x6E, 0x75, 0x6C, 0x6C])
            return .null
        case 0x2D, 0x30...0x39:
            return .number(try parseNumber())
        default:
            throw ClientRuntimeJSONCodecError.malformedJSON(offset: index)
        }
    }

    private mutating func parseObject(
        depth: Int
    ) throws -> ClientRuntimeEmbeddedJSONValue {
        index += 1
        skipWhitespace()
        var result: [String: ClientRuntimeEmbeddedJSONValue] = [:]
        if consume(0x7D) {
            return .object(result)
        }
        while true {
            guard index < bytes.count, bytes[index] == 0x22 else {
                throw ClientRuntimeJSONCodecError.malformedJSON(offset: index)
            }
            let key = try parseString()
            skipWhitespace()
            guard consume(0x3A) else {
                throw ClientRuntimeJSONCodecError.malformedJSON(offset: index)
            }
            skipWhitespace()
            result[key] = try parseValue(depth: depth)
            skipWhitespace()
            if consume(0x7D) {
                return .object(result)
            }
            guard consume(0x2C) else {
                throw ClientRuntimeJSONCodecError.malformedJSON(offset: index)
            }
            skipWhitespace()
        }
    }

    private mutating func parseArray(
        depth: Int
    ) throws -> ClientRuntimeEmbeddedJSONValue {
        index += 1
        skipWhitespace()
        var result: [ClientRuntimeEmbeddedJSONValue] = []
        if consume(0x5D) {
            return .array(result)
        }
        while true {
            result.append(try parseValue(depth: depth))
            skipWhitespace()
            if consume(0x5D) {
                return .array(result)
            }
            guard consume(0x2C) else {
                throw ClientRuntimeJSONCodecError.malformedJSON(offset: index)
            }
            skipWhitespace()
        }
    }

    private mutating func parseString() throws -> String {
        guard consume(0x22) else {
            throw ClientRuntimeJSONCodecError.malformedJSON(offset: index)
        }
        var result: [UInt8] = []
        while index < bytes.count {
            let byte = bytes[index]
            index += 1
            switch byte {
            case 0x22:
                guard let value = String(validating: result, as: UTF8.self) else {
                    throw ClientRuntimeJSONCodecError.malformedJSON(offset: index)
                }
                return value
            case 0x5C:
                try appendEscape(to: &result)
            case 0x00...0x1F:
                throw ClientRuntimeJSONCodecError.malformedJSON(offset: index - 1)
            default:
                result.append(byte)
            }
        }
        throw ClientRuntimeJSONCodecError.malformedJSON(offset: index)
    }

    private mutating func appendEscape(to result: inout [UInt8]) throws {
        guard index < bytes.count else {
            throw ClientRuntimeJSONCodecError.malformedJSON(offset: index)
        }
        let escape = bytes[index]
        index += 1
        switch escape {
        case 0x22, 0x5C, 0x2F:
            result.append(escape)
        case 0x62:
            result.append(0x08)
        case 0x66:
            result.append(0x0C)
        case 0x6E:
            result.append(0x0A)
        case 0x72:
            result.append(0x0D)
        case 0x74:
            result.append(0x09)
        case 0x75:
            let first = try parseHexQuad()
            let scalarValue: UInt32
            if (0xD800...0xDBFF).contains(first) {
                guard consume(0x5C), consume(0x75) else {
                    throw ClientRuntimeJSONCodecError.malformedJSON(offset: index)
                }
                let second = try parseHexQuad()
                guard (0xDC00...0xDFFF).contains(second) else {
                    throw ClientRuntimeJSONCodecError.malformedJSON(offset: index)
                }
                scalarValue = 0x10000
                    + (UInt32(first - 0xD800) << 10)
                    + UInt32(second - 0xDC00)
            } else {
                guard !(0xDC00...0xDFFF).contains(first) else {
                    throw ClientRuntimeJSONCodecError.malformedJSON(offset: index)
                }
                scalarValue = UInt32(first)
            }
            guard let scalar = Unicode.Scalar(scalarValue) else {
                throw ClientRuntimeJSONCodecError.malformedJSON(offset: index)
            }
            result.append(contentsOf: String(scalar).utf8)
        default:
            throw ClientRuntimeJSONCodecError.malformedJSON(offset: index - 1)
        }
    }

    private mutating func parseHexQuad() throws -> UInt16 {
        guard index + 4 <= bytes.count else {
            throw ClientRuntimeJSONCodecError.malformedJSON(offset: index)
        }
        var value: UInt16 = 0
        for _ in 0..<4 {
            let digit = bytes[index]
            index += 1
            value <<= 4
            switch digit {
            case 0x30...0x39:
                value += UInt16(digit - 0x30)
            case 0x41...0x46:
                value += UInt16(digit - 0x41 + 10)
            case 0x61...0x66:
                value += UInt16(digit - 0x61 + 10)
            default:
                throw ClientRuntimeJSONCodecError.malformedJSON(offset: index - 1)
            }
        }
        return value
    }

    private mutating func parseNumber() throws -> String {
        let start = index
        _ = consume(0x2D)
        if consume(0x30) {
            if index < bytes.count, (0x30...0x39).contains(bytes[index]) {
                throw ClientRuntimeJSONCodecError.malformedJSON(offset: index)
            }
        } else {
            guard consumeDigits(requireAtLeastOne: true) else {
                throw ClientRuntimeJSONCodecError.malformedJSON(offset: index)
            }
        }
        if consume(0x2E) {
            guard consumeDigits(requireAtLeastOne: true) else {
                throw ClientRuntimeJSONCodecError.malformedJSON(offset: index)
            }
        }
        if index < bytes.count, bytes[index] == 0x65 || bytes[index] == 0x45 {
            index += 1
            if index < bytes.count, bytes[index] == 0x2B || bytes[index] == 0x2D {
                index += 1
            }
            guard consumeDigits(requireAtLeastOne: true) else {
                throw ClientRuntimeJSONCodecError.malformedJSON(offset: index)
            }
        }
        return String(decoding: bytes[start..<index], as: UTF8.self)
    }

    private mutating func consumeDigits(requireAtLeastOne: Bool) -> Bool {
        let start = index
        while index < bytes.count, (0x30...0x39).contains(bytes[index]) {
            index += 1
        }
        return !requireAtLeastOne || index > start
    }

    private mutating func consumeLiteral(_ literal: [UInt8]) throws {
        guard index + literal.count <= bytes.count else {
            throw ClientRuntimeJSONCodecError.malformedJSON(offset: index)
        }
        for byte in literal {
            guard bytes[index] == byte else {
                throw ClientRuntimeJSONCodecError.malformedJSON(offset: index)
            }
            index += 1
        }
    }

    private mutating func consume(_ byte: UInt8) -> Bool {
        guard index < bytes.count, bytes[index] == byte else {
            return false
        }
        index += 1
        return true
    }

    private mutating func skipWhitespace() {
        while index < bytes.count {
            switch bytes[index] {
            case 0x20, 0x09, 0x0A, 0x0D:
                index += 1
            default:
                return
            }
        }
    }
}

private enum ClientRuntimeEmbeddedJSONEncoder {
    static func encode(_ value: ClientRuntimeEmbeddedJSONValue) -> [UInt8] {
        var bytes: [UInt8] = []
        append(value, to: &bytes)
        return bytes
    }

    private static func append(
        _ value: ClientRuntimeEmbeddedJSONValue,
        to bytes: inout [UInt8]
    ) {
        switch value {
        case .object(let object):
            bytes.append(0x7B)
            var first = true
            for key in object.keys.sorted() {
                if first {
                    first = false
                } else {
                    bytes.append(0x2C)
                }
                appendString(key, to: &bytes)
                bytes.append(0x3A)
                if let item = object[key] {
                    append(item, to: &bytes)
                }
            }
            bytes.append(0x7D)
        case .array(let array):
            bytes.append(0x5B)
            for (index, item) in array.enumerated() {
                if index > 0 {
                    bytes.append(0x2C)
                }
                append(item, to: &bytes)
            }
            bytes.append(0x5D)
        case .string(let string):
            appendString(string, to: &bytes)
        case .number(let number):
            bytes.append(contentsOf: number.utf8)
        case .boolean(let boolean):
            bytes.append(contentsOf: boolean ? [0x74, 0x72, 0x75, 0x65] : [0x66, 0x61, 0x6C, 0x73, 0x65])
        case .null:
            bytes.append(contentsOf: [0x6E, 0x75, 0x6C, 0x6C])
        }
    }

    private static func appendString(_ value: String, to bytes: inout [UInt8]) {
        bytes.append(0x22)
        for byte in value.utf8 {
            switch byte {
            case 0x22:
                bytes.append(contentsOf: [0x5C, 0x22])
            case 0x5C:
                bytes.append(contentsOf: [0x5C, 0x5C])
            case 0x08:
                bytes.append(contentsOf: [0x5C, 0x62])
            case 0x0C:
                bytes.append(contentsOf: [0x5C, 0x66])
            case 0x0A:
                bytes.append(contentsOf: [0x5C, 0x6E])
            case 0x0D:
                bytes.append(contentsOf: [0x5C, 0x72])
            case 0x09:
                bytes.append(contentsOf: [0x5C, 0x74])
            case 0x00...0x1F:
                let hex = Array("0123456789abcdef".utf8)
                bytes.append(contentsOf: [
                    0x5C, 0x75, 0x30, 0x30,
                    hex[Int(byte >> 4)],
                    hex[Int(byte & 0x0F)],
                ])
            default:
                bytes.append(byte)
            }
        }
        bytes.append(0x22)
    }
}

enum ClientRuntimeEmbeddedJSONCodec {
    static func decodeBootstrapRequest(
        from data: [UInt8]
    ) throws -> ClientRuntimeBootstrapRequest {
        var parser = ClientRuntimeEmbeddedJSONParser(data)
        let root = try object(try parser.parse(), path: "$")
        return ClientRuntimeBootstrapRequest(
            hydrationIndex: try hydrationIndex(
                try required(root, "hydrationIndex", path: "$"),
                path: "$.hydrationIndex"
            ),
            documentNodeIDUpperBound: try optionalInt(
                root["documentNodeIDUpperBound"],
                path: "$.documentNodeIDUpperBound"
            ),
            location: try bootstrapLocation(
                try required(root, "location", path: "$"),
                path: "$.location"
            ),
            mode: try bootstrapMode(root["mode"], path: "$.mode"),
            stateSnapshot: try optionalStateSnapshot(
                root["stateSnapshot"],
                path: "$.stateSnapshot"
            ),
            actorBindings: try actorBindings(
                root["actorBindings"],
                path: "$.actorBindings"
            ),
            actorRouteBindings: try actorRouteBindings(
                root["actorRouteBindings"],
                path: "$.actorRouteBindings"
            )
        )
    }

    static func decodeEventRequest(
        from data: [UInt8]
    ) throws -> ClientRuntimeEventRequest {
        var parser = ClientRuntimeEmbeddedJSONParser(data)
        let root = try object(try parser.parse(), path: "$")
        return ClientRuntimeEventRequest(
            handlerID: HandlerID(
                try rawString(
                    try required(root, "handlerID", path: "$"),
                    path: "$.handlerID"
                )
            ),
            event: try domEvent(
                try required(root, "event", path: "$"),
                path: "$.event"
            ),
            componentID: try optionalRawString(
                root["componentID"],
                path: "$.componentID"
            ).map(ComponentID.init)
        )
    }

    static func decodeStateSnapshot(
        from data: [UInt8]
    ) throws -> StateStoreSnapshot {
        var parser = ClientRuntimeEmbeddedJSONParser(data)
        return try stateSnapshot(try parser.parse(), path: "$")
    }

    static func encode(_ response: ClientRuntimeResponse) throws -> [UInt8] {
        var root: [String: ClientRuntimeEmbeddedJSONValue] = [
            "appliesDOMCommandsInRuntime": .boolean(response.appliesDOMCommandsInRuntime),
            "atomicStyleRules": .array(response.atomicStyleRules.map { rule in
                .object([
                    "className": .string(rule.className),
                    "body": .string(rule.body),
                ])
            }),
        ]
        if let commandBatch = response.commandBatch {
            root["commandBatch"] = commandBatchObject(commandBatch)
        }
        if let hydrationIndex = response.hydrationIndex {
            root["hydrationIndex"] = hydrationIndexObject(hydrationIndex)
        }
        if let error = response.error {
            root["error"] = .string(error)
        }
        return ClientRuntimeEmbeddedJSONEncoder.encode(.object(root))
    }

    static func encode(_ snapshot: StateStoreSnapshot) throws -> [UInt8] {
        ClientRuntimeEmbeddedJSONEncoder.encode(stateSnapshotObject(snapshot))
    }

    private static func hydrationIndex(
        _ input: ClientRuntimeEmbeddedJSONValue,
        path: String
    ) throws -> BrowserHydrationIndex {
        let input = try object(input, path: path)
        return BrowserHydrationIndex(
            rootID: HTMLNodeID(
                try rawInt(
                    try required(input, "rootID", path: path),
                    path: "\(path).rootID"
                )
            ),
            nodes: try array(
                try required(input, "nodes", path: path),
                path: "\(path).nodes"
            ).enumerated().map { index, value in
                try hydrationNode(value, path: "\(path).nodes[\(index)]")
            },
            components: try array(
                try required(input, "components", path: path),
                path: "\(path).components"
            ).enumerated().map { index, value in
                try hydrationComponent(value, path: "\(path).components[\(index)]")
            },
            serverSlots: try array(
                input["serverSlots"] ?? .array([]),
                path: "\(path).serverSlots"
            ).enumerated().map { index, value in
                try serverSlot(value, path: "\(path).serverSlots[\(index)]")
            },
            handlers: try array(
                input["handlers"] ?? .array([]),
                path: "\(path).handlers"
            ).enumerated().map { index, value in
                try eventBinding(value, path: "\(path).handlers[\(index)]")
            }
        )
    }

    private static func hydrationNode(
        _ input: ClientRuntimeEmbeddedJSONValue,
        path: String
    ) throws -> BrowserHydrationNodeRecord {
        let input = try object(input, path: path)
        guard
            let roleValue = try optionalString(input["role"], path: "\(path).role"),
            let role = BrowserHydrationNodeRole(rawValue: roleValue)
        else {
            throw ClientRuntimeJSONCodecError.invalidValue(
                path: "\(path).role",
                expected: "browser hydration node role"
            )
        }
        return BrowserHydrationNodeRecord(
            id: HTMLNodeID(
                try rawInt(
                    try required(input, "id", path: path),
                    path: "\(path).id"
                )
            ),
            parentID: try optionalRawInt(
                input["parentID"],
                path: "\(path).parentID"
            ).map(HTMLNodeID.init),
            childIDs: try array(
                input["childIDs"] ?? .array([]),
                path: "\(path).childIDs"
            ).enumerated().map { index, value in
                HTMLNodeID(try rawInt(value, path: "\(path).childIDs[\(index)]"))
            },
            role: role,
            name: try optionalString(input["name"], path: "\(path).name"),
            text: try optionalString(input["text"], path: "\(path).text"),
            componentID: try optionalRawString(
                input["componentID"],
                path: "\(path).componentID"
            ).map(ComponentID.init),
            serverSlotID: try optionalRawString(
                input["serverSlotID"],
                path: "\(path).serverSlotID"
            ).map { ServerSlotID($0) },
            attributes: try array(
                input["attributes"] ?? .array([]),
                path: "\(path).attributes"
            ).enumerated().map { index, value in
                try attribute(value, path: "\(path).attributes[\(index)]")
            },
            eventBindings: try array(
                input["eventBindings"] ?? .array([]),
                path: "\(path).eventBindings"
            ).enumerated().map { index, value in
                try eventBinding(value, path: "\(path).eventBindings[\(index)]")
            },
            key: try optionalKey(input["key"], path: "\(path).key"),
            fingerprint: NodeFingerprint(
                try rawUInt64(
                    try required(input, "fingerprint", path: path),
                    path: "\(path).fingerprint"
                )
            )
        )
    }

    private static func hydrationComponent(
        _ input: ClientRuntimeEmbeddedJSONValue,
        path: String
    ) throws -> BrowserHydrationComponentRecord {
        let input = try object(input, path: path)
        guard
            let loadPolicyValue = try optionalString(
                input["loadPolicy"],
                path: "\(path).loadPolicy"
            ),
            let loadPolicy = ClientLoadPolicy(rawValue: loadPolicyValue)
        else {
            throw ClientRuntimeJSONCodecError.invalidValue(
                path: "\(path).loadPolicy",
                expected: "client load policy"
            )
        }
        return BrowserHydrationComponentRecord(
            id: ComponentID(
                try rawString(
                    try required(input, "id", path: path),
                    path: "\(path).id"
                )
            ),
            typeName: try string(
                try required(input, "typeName", path: path),
                path: "\(path).typeName"
            ),
            path: try string(
                try required(input, "path", path: path),
                path: "\(path).path"
            ),
            nodeID: HTMLNodeID(
                try rawInt(
                    try required(input, "nodeID", path: path),
                    path: "\(path).nodeID"
                )
            ),
            bundleID: try optionalRawString(
                input["bundleID"],
                path: "\(path).bundleID"
            ).map { ClientBundleID($0) },
            loadPolicy: loadPolicy,
            serverSlotIDs: try array(
                input["serverSlotIDs"] ?? .array([]),
                path: "\(path).serverSlotIDs"
            ).enumerated().map { index, value in
                ServerSlotID(
                    try rawString(value, path: "\(path).serverSlotIDs[\(index)]")
                )
            },
            stateSlots: try array(
                input["stateSlots"] ?? .array([]),
                path: "\(path).stateSlots"
            ).enumerated().map { index, value in
                try stateSlot(value, path: "\(path).stateSlots[\(index)]")
            },
            environmentSnapshot: try environmentSnapshot(
                input["environmentSnapshot"] ?? .object(["values": .array([])]),
                path: "\(path).environmentSnapshot"
            )
        )
    }

    private static func serverSlot(
        _ input: ClientRuntimeEmbeddedJSONValue,
        path: String
    ) throws -> ServerSlotRecord {
        let input = try object(input, path: path)
        return ServerSlotRecord(
            id: ServerSlotID(
                try rawString(
                    try required(input, "id", path: path),
                    path: "\(path).id"
                )
            ),
            ownerComponentID: ComponentID(
                try rawString(
                    try required(input, "ownerComponentID", path: path),
                    path: "\(path).ownerComponentID"
                )
            ),
            componentType: try string(
                try required(input, "componentType", path: path),
                path: "\(path).componentType"
            ),
            path: try string(
                try required(input, "path", path: path),
                path: "\(path).path"
            ),
            nodeID: HTMLNodeID(
                try rawInt(
                    try required(input, "nodeID", path: path),
                    path: "\(path).nodeID"
                )
            )
        )
    }

    private static func eventBinding(
        _ input: ClientRuntimeEmbeddedJSONValue,
        path: String
    ) throws -> BrowserHydrationEventBinding {
        let input = try object(input, path: path)
        return BrowserHydrationEventBinding(
            nodeID: HTMLNodeID(
                try rawInt(
                    try required(input, "nodeID", path: path),
                    path: "\(path).nodeID"
                )
            ),
            handlerID: HandlerID(
                try rawString(
                    try required(input, "handlerID", path: path),
                    path: "\(path).handlerID"
                )
            ),
            eventName: try string(
                try required(input, "eventName", path: path),
                path: "\(path).eventName"
            ),
            componentID: try optionalRawString(
                input["componentID"],
                path: "\(path).componentID"
            ).map(ComponentID.init)
        )
    }

    private static func attribute(
        _ input: ClientRuntimeEmbeddedJSONValue,
        path: String
    ) throws -> HTMLAttributeRecord {
        let input = try object(input, path: path)
        return HTMLAttributeRecord(
            name: try string(
                try required(input, "name", path: path),
                path: "\(path).name"
            ),
            value: try optionalString(input["value"], path: "\(path).value"),
            kind: try attributeKind(
                try required(input, "kind", path: path),
                path: "\(path).kind"
            ),
            handlerID: try optionalRawString(
                input["handlerID"],
                path: "\(path).handlerID"
            ).map(HandlerID.init),
            eventName: try optionalString(
                input["eventName"],
                path: "\(path).eventName"
            )
        )
    }

    private static func attributeKind(
        _ input: ClientRuntimeEmbeddedJSONValue,
        path: String
    ) throws -> HTMLAttributeKind {
        let name: String
        switch input {
        case .string(let value):
            name = value
        case .object(let value):
            guard let first = value.keys.first else {
                throw ClientRuntimeJSONCodecError.invalidValue(
                    path: path,
                    expected: "HTML attribute kind"
                )
            }
            name = first
        default:
            throw ClientRuntimeJSONCodecError.invalidValue(
                path: path,
                expected: "HTML attribute kind"
            )
        }
        switch name {
        case "string": return .string
        case "boolean": return .boolean
        case "tokenList": return .tokenList
        case "url": return .url
        case "urlList": return .urlList
        case "propertyBinding": return .propertyBinding
        case "eventBinding": return .eventBinding
        case "raw": return .raw
        default:
            throw ClientRuntimeJSONCodecError.unsupportedValue(path: path, value: name)
        }
    }

    private static func optionalKey(
        _ input: ClientRuntimeEmbeddedJSONValue?,
        path: String
    ) throws -> Key? {
        guard let input, !isNull(input) else {
            return nil
        }
        let objectValue = try object(input, path: path)
        return Key(
            rawValue: try string(
                try required(objectValue, "rawValue", path: path),
                path: "\(path).rawValue"
            ),
            identity: try string(
                try required(objectValue, "identity", path: path),
                path: "\(path).identity"
            )
        )
    }

    private static func stateSlot(
        _ input: ClientRuntimeEmbeddedJSONValue,
        path: String
    ) throws -> StateSlotRecord {
        let input = try object(input, path: path)
        let source = try object(
            try required(input, "source", path: path),
            path: "\(path).source"
        )
        return StateSlotRecord(
            id: StateSlotID(
                try rawString(
                    try required(input, "id", path: path),
                    path: "\(path).id"
                )
            ),
            componentID: ComponentID(
                try rawString(
                    try required(input, "componentID", path: path),
                    path: "\(path).componentID"
                )
            ),
            valueType: try string(
                try required(input, "valueType", path: path),
                path: "\(path).valueType"
            ),
            source: StateSourceLocation(
                fileID: try string(
                    try required(source, "fileID", path: "\(path).source"),
                    path: "\(path).source.fileID"
                ),
                line: UInt(
                    try int(
                        try required(source, "line", path: "\(path).source"),
                        path: "\(path).source.line"
                    )
                ),
                column: UInt(
                    try int(
                        try required(source, "column", path: "\(path).source"),
                        path: "\(path).source.column"
                    )
                )
            )
        )
    }

    private static func environmentSnapshot(
        _ input: ClientRuntimeEmbeddedJSONValue,
        path: String
    ) throws -> ClientEnvironmentSnapshot {
        let input = try object(input, path: path)
        return ClientEnvironmentSnapshot(
            values: try array(
                input["values"] ?? .array([]),
                path: "\(path).values"
            ).enumerated().map { index, item in
                let itemPath = "\(path).values[\(index)]"
                let item = try object(item, path: itemPath)
                return ClientEnvironmentSnapshotValue(
                    key: try string(
                        try required(item, "key", path: itemPath),
                        path: "\(itemPath).key"
                    ),
                    valueType: try string(
                        try required(item, "valueType", path: itemPath),
                        path: "\(itemPath).valueType"
                    ),
                    encoding: try string(
                        try required(item, "encoding", path: itemPath),
                        path: "\(itemPath).encoding"
                    ),
                    encodedValue: try string(
                        try required(item, "encodedValue", path: itemPath),
                        path: "\(itemPath).encodedValue"
                    )
                )
            }
        )
    }

    private static func bootstrapLocation(
        _ input: ClientRuntimeEmbeddedJSONValue,
        path: String
    ) throws -> ClientRuntimeBootstrapLocation {
        let input = try object(input, path: path)
        return ClientRuntimeBootstrapLocation(
            href: try string(
                try required(input, "href", path: path),
                path: "\(path).href"
            ),
            search: try string(
                try required(input, "search", path: path),
                path: "\(path).search"
            )
        )
    }

    private static func bootstrapMode(
        _ input: ClientRuntimeEmbeddedJSONValue?,
        path: String
    ) throws -> ClientRuntimeBootstrapMode? {
        guard let rawValue = try optionalString(input, path: path) else {
            return nil
        }
        guard let mode = ClientRuntimeBootstrapMode(rawValue: rawValue) else {
            throw ClientRuntimeJSONCodecError.unsupportedValue(path: path, value: rawValue)
        }
        return mode
    }

    private static func actorBindings(
        _ input: ClientRuntimeEmbeddedJSONValue?,
        path: String
    ) throws -> [SwiftWebActorBindingRecord] {
        try array(input ?? .array([]), path: path).enumerated().map { index, item in
            let itemPath = "\(path)[\(index)]"
            let item = try object(item, path: itemPath)
            let contractKey = try string(
                try required(item, "contractKey", path: itemPath),
                path: "\(itemPath).contractKey"
            )
            #if SWIFTWEB_LEGACY_ACTORS
            if let legacyActorID = try optionalString(
                item["actorID"],
                path: "\(itemPath).actorID"
            ) {
                return SwiftWebActorBindingRecord(
                    contractKey: contractKey,
                    actorID: legacyActorID
                )
            }
            #endif
            return SwiftWebActorBindingRecord(
                contractKey: contractKey,
                actorID: ActorAddress(
                    type: ActorTypeID(
                        high: try uint64(
                            try required(item, "actorTypeHigh", path: itemPath),
                            path: "\(itemPath).actorTypeHigh"
                        ),
                        low: try uint64(
                            try required(item, "actorTypeLow", path: itemPath),
                            path: "\(itemPath).actorTypeLow"
                        )
                    ),
                    identity: try string(
                        try required(item, "actorIdentity", path: itemPath),
                        path: "\(itemPath).actorIdentity"
                    )
                )
            )
        }
    }

    private static func actorRouteBindings(
        _ input: ClientRuntimeEmbeddedJSONValue?,
        path: String
    ) throws -> [SwiftWebActorRouteBindingRecord] {
        try array(input ?? .array([]), path: path).enumerated().map { index, item in
            let itemPath = "\(path)[\(index)]"
            let item = try object(item, path: itemPath)
            return SwiftWebActorRouteBindingRecord(
                actorID: ActorAddress(
                    type: ActorTypeID(
                        high: try uint64(
                            try required(item, "actorTypeHigh", path: itemPath),
                            path: "\(itemPath).actorTypeHigh"
                        ),
                        low: try uint64(
                            try required(item, "actorTypeLow", path: itemPath),
                            path: "\(itemPath).actorTypeLow"
                        )
                    ),
                    identity: try string(
                        try required(item, "actorIdentity", path: itemPath),
                        path: "\(itemPath).actorIdentity"
                    )
                ),
                route: ActorRoute(
                    transport: ActorTransportID(
                        try string(
                            try required(item, "transport", path: itemPath),
                            path: "\(itemPath).transport"
                        )
                    ),
                    endpoint: ActorEndpoint(
                        try string(
                            try required(item, "endpoint", path: itemPath),
                            path: "\(itemPath).endpoint"
                        )
                    )
                )
            )
        }
    }

    private static func optionalStateSnapshot(
        _ input: ClientRuntimeEmbeddedJSONValue?,
        path: String
    ) throws -> StateStoreSnapshot? {
        guard let input, !isNull(input) else {
            return nil
        }
        return try stateSnapshot(input, path: path)
    }

    private static func stateSnapshot(
        _ input: ClientRuntimeEmbeddedJSONValue,
        path: String
    ) throws -> StateStoreSnapshot {
        let input = try object(input, path: path)
        let rawValues = try object(
            try required(input, "values", path: path),
            path: "\(path).values"
        )
        var values: [String: StateSnapshotValue] = [:]
        values.reserveCapacity(rawValues.count)
        for (key, rawValue) in rawValues {
            let itemPath = "\(path).values.\(key)"
            let rawValue = try object(rawValue, path: itemPath)
            values[key] = StateSnapshotValue(
                valueType: try string(
                    try required(rawValue, "valueType", path: itemPath),
                    path: "\(itemPath).valueType"
                ),
                encoding: try string(
                    try required(rawValue, "encoding", path: itemPath),
                    path: "\(itemPath).encoding"
                ),
                encodedValue: try string(
                    try required(rawValue, "encodedValue", path: itemPath),
                    path: "\(itemPath).encodedValue"
                )
            )
        }
        return StateStoreSnapshot(
            schemaHash: try string(
                try required(input, "schemaHash", path: path),
                path: "\(path).schemaHash"
            ),
            values: values
        )
    }

    private static func domEvent(
        _ input: ClientRuntimeEmbeddedJSONValue,
        path: String
    ) throws -> DOMEvent {
        let input = try object(input, path: path)
        var metadata: [String: String] = [:]
        if let rawMetadata = input["metadata"], !isNull(rawMetadata) {
            let metadataObject = try object(rawMetadata, path: "\(path).metadata")
            metadata.reserveCapacity(metadataObject.count)
            for (key, value) in metadataObject {
                metadata[key] = try string(value, path: "\(path).metadata.\(key)")
            }
        }
        return DOMEvent(
            value: try optionalString(input["value"], path: "\(path).value"),
            checked: try optionalBool(input["checked"], path: "\(path).checked"),
            key: try optionalString(input["key"], path: "\(path).key"),
            code: try optionalString(input["code"], path: "\(path).code"),
            inputType: try optionalString(input["inputType"], path: "\(path).inputType"),
            clientX: try optionalDouble(input["clientX"], path: "\(path).clientX"),
            clientY: try optionalDouble(input["clientY"], path: "\(path).clientY"),
            metadata: metadata
        )
    }

    private static func commandBatchObject(
        _ batch: BrowserDOMCommandBatch
    ) -> ClientRuntimeEmbeddedJSONValue {
        .object(["commands": .array(batch.commands.map(commandObject))])
    }

    private static func commandObject(
        _ command: BrowserDOMCommand
    ) -> ClientRuntimeEmbeddedJSONValue {
        switch command {
        case .replaceNode(let node, let replacement):
            return .object([
                "replaceNode": .object([
                    "node": nodeObject(node),
                    "replacement": nodeObject(replacement),
                ]),
            ])
        case .replaceSubtree(let node, let html):
            return .object([
                "replaceSubtree": .object([
                    "node": nodeObject(node),
                    "html": .string(html),
                ]),
            ])
        case .updateText(let node, let value):
            return .object([
                "updateText": .object([
                    "node": nodeObject(node),
                    "value": .string(value),
                ]),
            ])
        case .updateComment(let node, let value):
            return .object([
                "updateComment": .object([
                    "node": nodeObject(node),
                    "value": .string(value),
                ]),
            ])
        case .updateAttributes(let node, let attributes):
            return .object([
                "updateAttributes": .object([
                    "node": nodeObject(node),
                    "attributes": .array(attributes.map(attributeObject)),
                ]),
            ])
        case .setProperty(let node, let name, let value):
            return .object([
                "setProperty": .object([
                    "node": nodeObject(node),
                    "name": .string(name),
                    "value": value.map(ClientRuntimeEmbeddedJSONValue.string) ?? .null,
                ]),
            ])
        case .insertNode(let parent, let index, let node):
            return .object([
                "insertNode": .object([
                    "parent": nodeObject(parent),
                    "index": .number(String(index)),
                    "node": nodeObject(node),
                ]),
            ])
        case .insertHTML(let parent, let index, let html):
            return .object([
                "insertHTML": .object([
                    "parent": nodeObject(parent),
                    "index": .number(String(index)),
                    "html": .string(html),
                ]),
            ])
        case .remove(let parent, let index, let node):
            return .object([
                "remove": .object([
                    "parent": nodeObject(parent),
                    "index": .number(String(index)),
                    "node": nodeObject(node),
                ]),
            ])
        case .move(let parent, let from, let to, let key):
            return .object([
                "move": .object([
                    "parent": nodeObject(parent),
                    "from": .number(String(from)),
                    "to": .number(String(to)),
                    "key": keyObject(key),
                ]),
            ])
        case .moveKeyed(let parent, let key, let to):
            return .object([
                "moveKeyed": .object([
                    "parent": nodeObject(parent),
                    "key": keyObject(key),
                    "to": .number(String(to)),
                ]),
            ])
        }
    }

    private static func hydrationIndexObject(
        _ index: BrowserHydrationIndex
    ) -> ClientRuntimeEmbeddedJSONValue {
        .object([
            "rootID": nodeObject(index.rootID),
            "nodes": .array(index.nodes.map(hydrationNodeObject)),
            "components": .array(index.components.map(hydrationComponentObject)),
            "serverSlots": .array(index.serverSlots.map(serverSlotObject)),
            "handlers": .array(index.handlers.map(eventBindingObject)),
        ])
    }

    private static func hydrationNodeObject(
        _ node: BrowserHydrationNodeRecord
    ) -> ClientRuntimeEmbeddedJSONValue {
        var value: [String: ClientRuntimeEmbeddedJSONValue] = [
            "id": nodeObject(node.id),
            "childIDs": .array(node.childIDs.map(nodeObject)),
            "role": .string(node.role.rawValue),
            "attributes": .array(node.attributes.map(attributeObject)),
            "eventBindings": .array(node.eventBindings.map(eventBindingObject)),
            "fingerprint": .object(["rawValue": .number(String(node.fingerprint.rawValue))]),
        ]
        if let parentID = node.parentID {
            value["parentID"] = nodeObject(parentID)
        }
        if let name = node.name {
            value["name"] = .string(name)
        }
        if let text = node.text {
            value["text"] = .string(text)
        }
        if let componentID = node.componentID {
            value["componentID"] = componentObject(componentID)
        }
        if let serverSlotID = node.serverSlotID {
            value["serverSlotID"] = .string(serverSlotID.rawValue)
        }
        if let key = node.key {
            value["key"] = keyObject(key)
        }
        return .object(value)
    }

    private static func hydrationComponentObject(
        _ component: BrowserHydrationComponentRecord
    ) -> ClientRuntimeEmbeddedJSONValue {
        var value: [String: ClientRuntimeEmbeddedJSONValue] = [
            "id": componentObject(component.id),
            "typeName": .string(component.typeName),
            "path": .string(component.path),
            "nodeID": nodeObject(component.nodeID),
            "loadPolicy": .string(component.loadPolicy.rawValue),
            "serverSlotIDs": .array(component.serverSlotIDs.map { .string($0.rawValue) }),
            "stateSlots": .array(component.stateSlots.map(stateSlotObject)),
            "environmentSnapshot": environmentSnapshotObject(component.environmentSnapshot),
        ]
        if let bundleID = component.bundleID {
            value["bundleID"] = .string(bundleID.rawValue)
        }
        return .object(value)
    }

    private static func serverSlotObject(
        _ slot: ServerSlotRecord
    ) -> ClientRuntimeEmbeddedJSONValue {
        .object([
            "id": .string(slot.id.rawValue),
            "ownerComponentID": componentObject(slot.ownerComponentID),
            "componentType": .string(slot.componentType),
            "path": .string(slot.path),
            "nodeID": nodeObject(slot.nodeID),
        ])
    }

    private static func eventBindingObject(
        _ binding: BrowserHydrationEventBinding
    ) -> ClientRuntimeEmbeddedJSONValue {
        var value: [String: ClientRuntimeEmbeddedJSONValue] = [
            "nodeID": nodeObject(binding.nodeID),
            "handlerID": handlerObject(binding.handlerID),
            "eventName": .string(binding.eventName),
        ]
        if let componentID = binding.componentID {
            value["componentID"] = componentObject(componentID)
        }
        return .object(value)
    }

    private static func attributeObject(
        _ attribute: HTMLAttributeRecord
    ) -> ClientRuntimeEmbeddedJSONValue {
        var value: [String: ClientRuntimeEmbeddedJSONValue] = [
            "name": .string(attribute.name),
            "kind": .object([attributeKindName(attribute.kind): .object([:])]),
        ]
        if let attributeValue = attribute.value {
            value["value"] = .string(attributeValue)
        }
        if let handlerID = attribute.handlerID {
            value["handlerID"] = handlerObject(handlerID)
        }
        if let eventName = attribute.eventName {
            value["eventName"] = .string(eventName)
        }
        return .object(value)
    }

    private static func attributeKindName(_ kind: HTMLAttributeKind) -> String {
        switch kind {
        case .string: "string"
        case .boolean: "boolean"
        case .tokenList: "tokenList"
        case .url: "url"
        case .urlList: "urlList"
        case .propertyBinding: "propertyBinding"
        case .eventBinding: "eventBinding"
        case .raw: "raw"
        }
    }

    private static func stateSlotObject(
        _ slot: StateSlotRecord
    ) -> ClientRuntimeEmbeddedJSONValue {
        .object([
            "id": .object(["rawValue": .string(slot.id.rawValue)]),
            "componentID": componentObject(slot.componentID),
            "valueType": .string(slot.valueType),
            "source": .object([
                "fileID": .string(slot.source.fileID),
                "line": .number(String(slot.source.line)),
                "column": .number(String(slot.source.column)),
            ]),
        ])
    }

    private static func environmentSnapshotObject(
        _ snapshot: ClientEnvironmentSnapshot
    ) -> ClientRuntimeEmbeddedJSONValue {
        .object([
            "values": .array(snapshot.values.map { value in
                .object([
                    "key": .string(value.key),
                    "valueType": .string(value.valueType),
                    "encoding": .string(value.encoding),
                    "encodedValue": .string(value.encodedValue),
                ])
            }),
        ])
    }

    private static func stateSnapshotObject(
        _ snapshot: StateStoreSnapshot
    ) -> ClientRuntimeEmbeddedJSONValue {
        var values: [String: ClientRuntimeEmbeddedJSONValue] = [:]
        values.reserveCapacity(snapshot.values.count)
        for (key, value) in snapshot.values {
            values[key] = .object([
                "valueType": .string(value.valueType),
                "encoding": .string(value.encoding),
                "encodedValue": .string(value.encodedValue),
            ])
        }
        return .object([
            "schemaHash": .string(snapshot.schemaHash),
            "values": .object(values),
        ])
    }

    private static func nodeObject(
        _ id: HTMLNodeID
    ) -> ClientRuntimeEmbeddedJSONValue {
        .object(["rawValue": .number(String(id.rawValue))])
    }

    private static func componentObject(
        _ id: ComponentID
    ) -> ClientRuntimeEmbeddedJSONValue {
        .object(["rawValue": .string(id.rawValue)])
    }

    private static func handlerObject(
        _ id: HandlerID
    ) -> ClientRuntimeEmbeddedJSONValue {
        .object(["rawValue": .string(id.rawValue)])
    }

    private static func keyObject(
        _ key: Key
    ) -> ClientRuntimeEmbeddedJSONValue {
        .object([
            "rawValue": .string(key.rawValue),
            "identity": .string(key.identity),
        ])
    }

    private static func required(
        _ object: [String: ClientRuntimeEmbeddedJSONValue],
        _ key: String,
        path: String
    ) throws -> ClientRuntimeEmbeddedJSONValue {
        guard let value = object[key], !isNull(value) else {
            throw ClientRuntimeJSONCodecError.invalidValue(
                path: "\(path).\(key)",
                expected: "value"
            )
        }
        return value
    }

    private static func object(
        _ input: ClientRuntimeEmbeddedJSONValue,
        path: String
    ) throws -> [String: ClientRuntimeEmbeddedJSONValue] {
        guard case .object(let value) = input else {
            throw ClientRuntimeJSONCodecError.invalidValue(path: path, expected: "object")
        }
        return value
    }

    private static func array(
        _ input: ClientRuntimeEmbeddedJSONValue,
        path: String
    ) throws -> [ClientRuntimeEmbeddedJSONValue] {
        guard case .array(let value) = input else {
            throw ClientRuntimeJSONCodecError.invalidValue(path: path, expected: "array")
        }
        return value
    }

    private static func string(
        _ input: ClientRuntimeEmbeddedJSONValue,
        path: String
    ) throws -> String {
        guard case .string(let value) = input else {
            throw ClientRuntimeJSONCodecError.invalidValue(path: path, expected: "string")
        }
        return value
    }

    private static func optionalString(
        _ input: ClientRuntimeEmbeddedJSONValue?,
        path: String
    ) throws -> String? {
        guard let input, !isNull(input) else {
            return nil
        }
        return try string(input, path: path)
    }

    private static func int(
        _ input: ClientRuntimeEmbeddedJSONValue,
        path: String
    ) throws -> Int {
        guard case .number(let value) = input,
              !value.contains("."),
              !value.contains("e"),
              !value.contains("E"),
              let integer = Int(value) else {
            throw ClientRuntimeJSONCodecError.invalidValue(path: path, expected: "integer")
        }
        return integer
    }

    private static func optionalInt(
        _ input: ClientRuntimeEmbeddedJSONValue?,
        path: String
    ) throws -> Int? {
        guard let input, !isNull(input) else {
            return nil
        }
        return try int(input, path: path)
    }

    private static func uint64(
        _ input: ClientRuntimeEmbeddedJSONValue,
        path: String
    ) throws -> UInt64 {
        let encodedValue: String
        switch input {
        case .string(let value):
            encodedValue = value
        case .number(let value)
            where !value.contains(".") && !value.contains("e") && !value.contains("E"):
            encodedValue = value
        default:
            throw ClientRuntimeJSONCodecError.invalidValue(
                path: path,
                expected: "unsigned integer string or number"
            )
        }
        guard let integer = UInt64(encodedValue) else {
            throw ClientRuntimeJSONCodecError.invalidValue(
                path: path,
                expected: "unsigned integer string or number"
            )
        }
        return integer
    }

    private static func optionalBool(
        _ input: ClientRuntimeEmbeddedJSONValue?,
        path: String
    ) throws -> Bool? {
        guard let input, !isNull(input) else {
            return nil
        }
        guard case .boolean(let value) = input else {
            throw ClientRuntimeJSONCodecError.invalidValue(path: path, expected: "boolean")
        }
        return value
    }

    private static func optionalDouble(
        _ input: ClientRuntimeEmbeddedJSONValue?,
        path: String
    ) throws -> Double? {
        guard let input, !isNull(input) else {
            return nil
        }
        guard case .number(let value) = input,
              let number = Double(value),
              number.isFinite else {
            throw ClientRuntimeJSONCodecError.invalidValue(path: path, expected: "number")
        }
        return number
    }

    private static func rawString(
        _ input: ClientRuntimeEmbeddedJSONValue,
        path: String
    ) throws -> String {
        if case .string(let value) = input {
            return value
        }
        let input = try object(input, path: path)
        return try string(
            try required(input, "rawValue", path: path),
            path: "\(path).rawValue"
        )
    }

    private static func optionalRawString(
        _ input: ClientRuntimeEmbeddedJSONValue?,
        path: String
    ) throws -> String? {
        guard let input, !isNull(input) else {
            return nil
        }
        return try rawString(input, path: path)
    }

    private static func rawInt(
        _ input: ClientRuntimeEmbeddedJSONValue,
        path: String
    ) throws -> Int {
        if case .number = input {
            return try int(input, path: path)
        }
        let input = try object(input, path: path)
        return try int(
            try required(input, "rawValue", path: path),
            path: "\(path).rawValue"
        )
    }

    private static func optionalRawInt(
        _ input: ClientRuntimeEmbeddedJSONValue?,
        path: String
    ) throws -> Int? {
        guard let input, !isNull(input) else {
            return nil
        }
        return try rawInt(input, path: path)
    }

    private static func rawUInt64(
        _ input: ClientRuntimeEmbeddedJSONValue,
        path: String
    ) throws -> UInt64 {
        if case .number = input {
            return try uint64(input, path: path)
        }
        let input = try object(input, path: path)
        return try uint64(
            try required(input, "rawValue", path: path),
            path: "\(path).rawValue"
        )
    }

    private static func isNull(_ input: ClientRuntimeEmbeddedJSONValue) -> Bool {
        if case .null = input {
            return true
        }
        return false
    }
}

#if hasFeature(Embedded)
typealias ClientRuntimeJSONCodec = ClientRuntimeEmbeddedJSONCodec
#endif
