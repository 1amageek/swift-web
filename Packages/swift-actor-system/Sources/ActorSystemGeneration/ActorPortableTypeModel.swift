public struct ActorPortableTypeModel: Hashable, Sendable {
    public enum Kind: Hashable, Sendable {
        case structure(fields: [ActorPortableFieldModel])
        case enumeration(cases: [ActorPortableCaseModel])
    }

    public let moduleName: String
    public let sourcePath: String
    public let imports: [String]
    public let name: String
    public let accessLevel: String
    public let conformances: [String]
    public let otherMembers: [String]
    public let kind: Kind

    public var symbol: String {
        "\(moduleName).\(name)"
    }
}

public struct ActorPortableFieldModel: Hashable, Sendable {
    public let name: String
    public let type: String
    public let defaultValue: String?
    public let source: String
}

public struct ActorPortableCaseModel: Hashable, Sendable {
    public let name: String
    public let associatedValues: [ActorPortableCaseValueModel]
    public let sourceElement: String
    public let isIndirect: Bool
}

public struct ActorPortableCaseValueModel: Hashable, Sendable {
    public let label: String?
    public let type: String
}
