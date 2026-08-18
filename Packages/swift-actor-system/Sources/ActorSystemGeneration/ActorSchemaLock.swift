import Foundation

public struct ActorSchemaLock: Codable, Hashable, Sendable {
    public static let currentFormatVersion = 3

    public var formatVersion: Int
    public var packageIdentity: String
    public var moduleName: String
    public var actors: [ActorSchemaLockActor]
    public var valueTypes: [ActorSchemaLockValueType]
    public var reservedActorTypeIDs: [ActorSchemaLockID128]
    public var reservedValueTypeIDs: [ActorSchemaLockID128]
    public var reservedMethodIDs: [UInt64]

    public init(
        formatVersion: Int = currentFormatVersion,
        packageIdentity: String,
        moduleName: String = "",
        actors: [ActorSchemaLockActor] = [],
        valueTypes: [ActorSchemaLockValueType] = [],
        reservedActorTypeIDs: [ActorSchemaLockID128] = [],
        reservedValueTypeIDs: [ActorSchemaLockID128] = [],
        reservedMethodIDs: [UInt64] = []
    ) {
        self.formatVersion = formatVersion
        self.packageIdentity = packageIdentity
        self.moduleName = moduleName
        self.actors = actors
        self.valueTypes = valueTypes
        self.reservedActorTypeIDs = reservedActorTypeIDs
        self.reservedValueTypeIDs = reservedValueTypeIDs
        self.reservedMethodIDs = reservedMethodIDs
    }
}

public struct ActorSchemaLockValueType: Codable, Hashable, Sendable {
    public var sourceType: String
    public var canonicalType: String
    public var typeID: ActorSchemaLockID128
    public var fields: [ActorSchemaLockValueField]
    public var cases: [ActorSchemaLockValueCase]
    public var reservedFieldIDs: [UInt32]
    public var reservedCaseIDs: [UInt32]

    public init(
        sourceType: String,
        canonicalType: String? = nil,
        typeID: ActorSchemaLockID128,
        fields: [ActorSchemaLockValueField],
        cases: [ActorSchemaLockValueCase],
        reservedFieldIDs: [UInt32],
        reservedCaseIDs: [UInt32]
    ) {
        self.sourceType = sourceType
        self.canonicalType = canonicalType ?? sourceType
        self.typeID = typeID
        self.fields = fields
        self.cases = cases
        self.reservedFieldIDs = reservedFieldIDs
        self.reservedCaseIDs = reservedCaseIDs
    }
}

public struct ActorSchemaLockValueField: Codable, Hashable, Sendable {
    public var fieldID: UInt32
    public var sourceName: String
    public var type: String
    public var isOptional: Bool
    public var defaultValue: String?
}

public struct ActorSchemaLockValueCase: Codable, Hashable, Sendable {
    public var caseID: UInt32
    public var sourceName: String
    public var associatedValues: [ActorSchemaLockParameter]
    public var reservedAssociatedValueFieldIDs: [UInt32]
}

public struct ActorSchemaLockActor: Codable, Hashable, Sendable {
    public var moduleName: String
    public var sourceSymbol: String
    public var sourcePath: String
    public var typeID: ActorSchemaLockID128
    public var schemaFingerprint: ActorSchemaLockID128
    public var methods: [ActorSchemaLockMethod]
    public var fields: [ActorSchemaLockField]
    public var reservedFieldIDs: [UInt32]

    public init(
        moduleName: String,
        sourceSymbol: String,
        sourcePath: String,
        typeID: ActorSchemaLockID128,
        schemaFingerprint: ActorSchemaLockID128,
        methods: [ActorSchemaLockMethod],
        fields: [ActorSchemaLockField],
        reservedFieldIDs: [UInt32]
    ) {
        self.moduleName = moduleName
        self.sourceSymbol = sourceSymbol
        self.sourcePath = sourcePath
        self.typeID = typeID
        self.schemaFingerprint = schemaFingerprint
        self.methods = methods
        self.fields = fields
        self.reservedFieldIDs = reservedFieldIDs
    }
}

public struct ActorSchemaLockMethod: Codable, Hashable, Sendable {
    public var sourceName: String
    public var canonicalSignature: String
    public var methodID: UInt64
    public var parameters: [ActorSchemaLockParameter]
    public var resultType: String
    public var errorType: String?
    public var compilerTargetAliases: [ActorSchemaLockCompilerAlias]
}

public struct ActorSchemaLockParameter: Codable, Hashable, Sendable {
    public var fieldID: UInt32
    public var label: String
    public var type: String
}

public struct ActorSchemaLockField: Codable, Hashable, Sendable {
    public var fieldID: UInt32
    public var sourceName: String
    public var type: String
    public var isOptional: Bool
    public var hasDefaultValue: Bool
}

public struct ActorSchemaLockCompilerAlias: Codable, Hashable, Sendable {
    public var toolchainFingerprint: String
    public var targetIdentifier: String
}

public struct ActorSchemaLockID128: Codable, Hashable, Sendable {
    public var high: UInt64
    public var low: UInt64

    public init(high: UInt64, low: UInt64) {
        self.high = high
        self.low = low
    }
}

public enum ActorSchemaLockStore {
    private struct Header: Decodable {
        let formatVersion: Int
    }

    public static func decode(_ data: Data) throws -> ActorSchemaLock {
        let decoder = JSONDecoder()
        let header = try decoder.decode(Header.self, from: data)
        guard header.formatVersion == ActorSchemaLock.currentFormatVersion else {
            throw ActorGenerationError.schemaConflict(
                reason: "Unsupported ActorSchema.lock format version \(header.formatVersion)"
            )
        }
        return try decoder.decode(ActorSchemaLock.self, from: data)
    }

    public static func load(
        from url: URL,
        packageIdentity: String,
        moduleName: String? = nil
    ) throws -> ActorSchemaLock {
        guard FileManager.default.fileExists(atPath: url.path) else {
            return ActorSchemaLock(
                packageIdentity: packageIdentity,
                moduleName: moduleName ?? ""
            )
        }
        let data = try Data(contentsOf: url)
        let lock = try decode(data)
        guard lock.packageIdentity == packageIdentity else {
            throw ActorGenerationError.schemaConflict(
                reason: "Package identity changed from \(lock.packageIdentity) to \(packageIdentity)"
            )
        }
        if let moduleName, lock.moduleName != moduleName {
            throw ActorGenerationError.schemaConflict(
                reason: "Actor schema module changed from \(lock.moduleName) to \(moduleName)"
            )
        }
        return lock
    }

    public static func save(_ lock: ActorSchemaLock, to url: URL) throws {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
        let data = try encoder.encode(lock)
        do {
            try FileManager.default.createDirectory(
                at: url.deletingLastPathComponent(),
                withIntermediateDirectories: true
            )
            try data.write(to: url, options: .atomic)
        } catch {
            throw ActorGenerationError.sourceWriteFailure(
                path: url.path,
                reason: String(describing: error)
            )
        }
    }
}
