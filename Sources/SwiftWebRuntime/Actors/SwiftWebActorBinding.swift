#if SWIFTWEB_ACTORS
@preconcurrency import Distributed
#endif

public struct SwiftWebActorContractKey: Sendable, Hashable, Codable {
    public let rawValue: String

    public init(_ rawValue: String) {
        self.rawValue = rawValue
    }

    #if SWIFTWEB_ACTORS
    public init<ActorType: DistributedActor>(_ actorType: ActorType.Type)
    where ActorType.ID == WebActorSystem.ActorID, ActorType.ActorSystem == WebActorSystem {
        self.rawValue = String(reflecting: actorType)
    }
    #endif
}

public struct SwiftWebActorBindingRecord: Sendable, Codable, Equatable {
    public let contractKey: String
    public let actorID: WebActorSystem.ActorID

    public init(contractKey: String, actorID: WebActorSystem.ActorID) {
        self.contractKey = contractKey
        self.actorID = actorID
    }

    public init(contract: SwiftWebActorContractKey, actorID: WebActorSystem.ActorID) {
        self.init(contractKey: contract.rawValue, actorID: actorID)
    }
}

public struct SwiftWebActorResolver: Sendable {
    public let contract: SwiftWebActorContractKey
    private let resolveValue: @Sendable (WebActorSystem.ActorID, WebActorSystem) throws -> any Sendable

    #if SWIFTWEB_ACTORS
    public init<Contract: DistributedActor>(_ contract: Contract.Type)
    where Contract.ID == WebActorSystem.ActorID, Contract.ActorSystem == WebActorSystem {
        self.init(contract: SwiftWebActorContractKey(contract), actorContract: contract)
    }

    public init<Contract: DistributedActor>(
        contract: SwiftWebActorContractKey,
        actorContract: Contract.Type
    ) where Contract.ID == WebActorSystem.ActorID, Contract.ActorSystem == WebActorSystem {
        self.contract = contract
        self.resolveValue = { actorID, actorSystem in
            try actorContract.resolve(id: actorID, using: actorSystem)
        }
    }
    #endif

    public init(
        contract: SwiftWebActorContractKey,
        resolve: @escaping @Sendable (WebActorSystem.ActorID, WebActorSystem) throws -> any Sendable
    ) {
        self.contract = contract
        self.resolveValue = resolve
    }

    func resolve<Service: Sendable>(
        _ service: Service.Type,
        actorID: WebActorSystem.ActorID,
        actorSystem: WebActorSystem
    ) throws -> Service {
        let value = try resolveValue(actorID, actorSystem)
        guard let service = value as? Service else {
            throw SwiftWebActorBindingError.typeMismatch(
                contract: contract.rawValue,
                expected: String(reflecting: Service.self),
                actual: String(reflecting: Swift.type(of: value))
            )
        }
        return service
    }
}

public struct SwiftWebActorResolverRegistry: Sendable {
    private let resolvers: [String: SwiftWebActorResolver]

    public init(_ resolvers: [SwiftWebActorResolver] = []) {
        var indexed: [String: SwiftWebActorResolver] = [:]
        for resolver in resolvers {
            indexed[resolver.contract.rawValue] = resolver
        }
        self.resolvers = indexed
    }

    public static let empty = SwiftWebActorResolverRegistry()

    public func registering(_ resolver: SwiftWebActorResolver) -> SwiftWebActorResolverRegistry {
        var next = resolvers
        next[resolver.contract.rawValue] = resolver
        return SwiftWebActorResolverRegistry(Array(next.values))
    }

    public func resolver(for contract: SwiftWebActorContractKey) throws -> SwiftWebActorResolver {
        guard let resolver = resolvers[contract.rawValue] else {
            throw SwiftWebActorBindingError.missingResolver(contract: contract.rawValue)
        }
        return resolver
    }
}

public struct SwiftWebActorBindingScope: Sendable {
    private let bindings: [String: SwiftWebActorBindingRecord]
    private let resolverRegistry: SwiftWebActorResolverRegistry
    private let actorSystems: [String: WebActorSystem]
    public let actorSystem: WebActorSystem

    public init(
        records: [SwiftWebActorBindingRecord] = [],
        resolverRegistry: SwiftWebActorResolverRegistry = .empty,
        actorSystem: WebActorSystem = .shared
    ) {
        var indexed: [String: SwiftWebActorBindingRecord] = [:]
        for record in records {
            indexed[record.contractKey] = record
        }
        self.init(
            bindings: indexed,
            resolverRegistry: resolverRegistry,
            actorSystem: actorSystem,
            actorSystems: Dictionary(
                uniqueKeysWithValues: indexed.keys.map { key in
                    (key, actorSystem)
                }
            )
        )
    }

    private init(
        bindings: [String: SwiftWebActorBindingRecord],
        resolverRegistry: SwiftWebActorResolverRegistry,
        actorSystem: WebActorSystem,
        actorSystems: [String: WebActorSystem]
    ) {
        self.bindings = bindings
        self.resolverRegistry = resolverRegistry
        self.actorSystem = actorSystem
        self.actorSystems = actorSystems
    }

    public static let empty = SwiftWebActorBindingScope()

    public var records: [SwiftWebActorBindingRecord] {
        bindings.values.sorted { left, right in
            left.contractKey < right.contractKey
        }
    }

    public func binding(for contract: SwiftWebActorContractKey) throws -> SwiftWebActorBindingRecord {
        guard let binding = bindings[contract.rawValue] else {
            throw SwiftWebActorBindingError.missingBinding(contract: contract.rawValue)
        }
        return binding
    }

    public func resolve<Service: Sendable>(
        _ service: Service.Type,
        contract: SwiftWebActorContractKey
    ) throws -> Service {
        let binding = try binding(for: contract)
        let resolver = try resolverRegistry.resolver(for: contract)
        let system = actorSystems[contract.rawValue] ?? actorSystem
        return try resolver.resolve(service, actorID: binding.actorID, actorSystem: system)
    }

    #if SWIFTWEB_ACTORS
    public func adding<ActorType: SwiftWebActorExporting>(
        _ actor: ActorType
    ) -> SwiftWebActorBindingScope {
        let contract = ActorType.swiftWebActorContractKey
        var records = bindings
        records[contract.rawValue] = SwiftWebActorBindingRecord(
            contract: contract,
            actorID: actor.id
        )
        let registry = resolverRegistry.registering(
            SwiftWebActorResolver(
                contract: contract,
                actorContract: ActorType.SwiftWebActorContract.self
            )
        )
        var systems = actorSystems
        systems[contract.rawValue] = actor.actorSystem
        return SwiftWebActorBindingScope(
            bindings: records,
            resolverRegistry: registry,
            actorSystem: actorSystem,
            actorSystems: systems
        )
    }
    #endif
}

public enum SwiftWebActorBindingContext {
    #if hasFeature(Embedded)
    nonisolated(unsafe) public static var current: SwiftWebActorBindingScope?

    public static func withValue<Result>(
        _ value: SwiftWebActorBindingScope,
        operation: () throws -> Result
    ) rethrows -> Result {
        let previous = current
        current = value
        defer { current = previous }
        return try operation()
    }
    #else
    @TaskLocal public static var current: SwiftWebActorBindingScope?

    public static func withValue<Result>(
        _ value: SwiftWebActorBindingScope,
        operation: () throws -> Result
    ) rethrows -> Result {
        try $current.withValue(value, operation: operation)
    }

    public static func withValue<Result: Sendable>(
        _ value: SwiftWebActorBindingScope,
        operation: @Sendable () async throws -> Result
    ) async rethrows -> Result {
        try await $current.withValue(value, operation: operation)
    }
    #endif
}

public enum SwiftWebActorBinding {
    public static func resolve<Service: Sendable>(
        _ service: Service.Type,
        contract: SwiftWebActorContractKey
    ) -> Service {
        guard let scope = SwiftWebActorBindingContext.current else {
            preconditionFailure("@Actor was accessed outside a SwiftWeb actor binding context")
        }
        do {
            return try scope.resolve(service, contract: contract)
        } catch {
            preconditionFailure("@Actor failed to resolve \(String(reflecting: Service.self)): \(error)")
        }
    }
}

public enum SwiftWebActorBindingError: Error, Sendable, CustomStringConvertible, Equatable {
    case missingBinding(contract: String)
    case missingResolver(contract: String)
    case typeMismatch(contract: String, expected: String, actual: String)

    public var description: String {
        switch self {
        case .missingBinding(let contract):
            "No actor binding was provided for \(contract)"
        case .missingResolver(let contract):
            "No actor resolver was registered for \(contract)"
        case .typeMismatch(let contract, let expected, let actual):
            "Actor resolver for \(contract) returned \(actual), expected \(expected)"
        }
    }
}
