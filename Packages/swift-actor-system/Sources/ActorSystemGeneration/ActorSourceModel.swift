public struct ActorSourceModel: Hashable, Sendable {
    public let moduleName: String
    public let sourcePath: String
    public let imports: [String]
    public let name: String
    public let accessLevel: String
    public let storedProperties: [ActorStoredPropertyModel]
    public let initializers: [ActorInitializerModel]
    public let methods: [ActorMethodModel]
    public let otherMembers: [String]

    public init(
        moduleName: String,
        sourcePath: String,
        imports: [String],
        name: String,
        accessLevel: String,
        storedProperties: [ActorStoredPropertyModel],
        initializers: [ActorInitializerModel],
        methods: [ActorMethodModel],
        otherMembers: [String]
    ) {
        self.moduleName = moduleName
        self.sourcePath = sourcePath
        self.imports = imports
        self.name = name
        self.accessLevel = accessLevel
        self.storedProperties = storedProperties
        self.initializers = initializers
        self.methods = methods
        self.otherMembers = otherMembers
    }

    public var symbol: String {
        "\(moduleName).\(name)"
    }
}

public struct ActorStoredPropertyModel: Hashable, Sendable {
    public let name: String
    public let type: String
    public let source: String
    public let modifiers: [String]
    public let accessLevel: String
    public let isImmutable: Bool
    public let hasAttributes: Bool
    public let hasObservers: Bool
    public let hasInitialValue: Bool
    public let initialValue: String?
}

public struct ActorInitializerModel: Hashable, Sendable {
    public let parameters: [ActorParameterModel]
    public let effects: String
    public let body: String
    public let bodyStatements: [String]
    public let accessLevel: String
}

public struct ActorMethodModel: Hashable, Sendable {
    public let name: String
    public let parameters: [ActorParameterModel]
    public let returnType: String
    public let isAsync: Bool
    public let throwsClause: String?
    public let body: String
    public let accessLevel: String

    public var canonicalSignature: String {
        let parameterTypes = parameters.map { "\($0.externalName):\($0.type)" }.joined(separator: ",")
        let asyncEffect = isAsync ? "async" : "sync"
        return "\(name)(\(parameterTypes))->\(returnType):\(asyncEffect):\(throwsClause ?? "nothrow")"
    }
}

public struct ActorParameterModel: Hashable, Sendable {
    public let externalName: String
    public let localName: String
    public let type: String
    public let defaultValue: String?
}
