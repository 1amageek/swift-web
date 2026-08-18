import ActorSystemCore
#if SWIFTWEB_ACTORS
import ActorSystemDistributed
@preconcurrency import Distributed
#endif

public struct SwiftWebActorContractKey: Sendable, Hashable {
    public let rawValue: String

    public init(_ rawValue: String) {
        self.rawValue = rawValue
    }

    public init<ActorType: ActorSchemaIdentifiable>(_ actorType: ActorType.Type) {
        let typeID = actorType.actorTypeDescriptor.id
        self.rawValue = "v1:\(String(typeID.high, radix: 16)):\(String(typeID.low, radix: 16))"
    }
}

public struct SwiftWebActorBindingRecord: Sendable, Equatable {
    public let contractKey: String
    public let actorID: ActorAddress

    public init(contractKey: String, actorID: ActorAddress) {
        self.contractKey = contractKey
        self.actorID = actorID
    }

    public init(contract: SwiftWebActorContractKey, actorID: ActorAddress) {
        self.init(contractKey: contract.rawValue, actorID: actorID)
    }

    #if SWIFTWEB_LEGACY_ACTORS
    @available(*, deprecated, message: "Use an ActorAddress actor ID")
    public init(contractKey: String, actorID: String) {
        self.init(
            contractKey: contractKey,
            actorID: legacyActorAddress(
                contract: SwiftWebActorContractKey(contractKey),
                actorID: actorID
            )
        )
    }
    #endif
}

public struct SwiftWebActorResolver: Sendable {
    public let contract: SwiftWebActorContractKey
    private let resolveValue: (@Sendable (ActorAddress, WebActorSystem) throws -> any Sendable)?
    #if SWIFTWEB_LEGACY_ACTORS
    private let legacyResolveValue: (@Sendable (
        LegacyWebActorSystem.ActorID,
        LegacyWebActorSystem
    ) throws -> any Sendable)?
    #endif

    public init<Contract: ActorSystemReference>(_ contract: Contract.Type)
    where Contract.ActorSystem == WebActorSystem {
        self.init(contract: SwiftWebActorContractKey(contract), actorContract: contract)
    }

    public init<Contract: ActorSystemReference>(
        contract: SwiftWebActorContractKey,
        actorContract: Contract.Type
    ) where Contract.ActorSystem == WebActorSystem {
        self.contract = contract
        self.resolveValue = { actorID, actorSystem in
            try actorContract.resolve(id: actorID, using: actorSystem)
        }
        #if SWIFTWEB_LEGACY_ACTORS
        self.legacyResolveValue = nil
        #endif
    }

    public init(
        contract: SwiftWebActorContractKey,
        resolve: @escaping @Sendable (ActorAddress, WebActorSystem) throws -> any Sendable
    ) {
        self.contract = contract
        self.resolveValue = resolve
        #if SWIFTWEB_LEGACY_ACTORS
        self.legacyResolveValue = nil
        #endif
    }

    #if SWIFTWEB_LEGACY_ACTORS
    @available(*, deprecated, message: "Use a concrete ActorSystemReference actor resolver")
    public init<Contract: DistributedActor>(
        legacyContract contract: SwiftWebActorContractKey,
        actorContract: Contract.Type
    ) where Contract.ID == LegacyWebActorSystem.ActorID,
            Contract.ActorSystem == LegacyWebActorSystem {
        self.contract = contract
        self.resolveValue = nil
        self.legacyResolveValue = { actorID, actorSystem in
            try actorContract.resolve(id: actorID, using: actorSystem)
        }
    }
    #endif

    #if SWIFTWEB_LEGACY_ACTORS
    func resolve<Service: Sendable>(
        _ service: Service.Type,
        actorID: ActorAddress,
        actorSystem: WebActorSystem,
        legacyActorSystem: LegacyWebActorSystem
    ) throws -> Service {
        let value: any Sendable
        if let resolve = resolveValue {
            value = try resolve(actorID, actorSystem)
        } else if let resolve = legacyResolveValue {
            value = try resolve(actorID.identity, legacyActorSystem)
        } else {
            throw SwiftWebActorBindingError.missingResolver(contract: contract.rawValue)
        }
        return try cast(value, to: service)
    }
    #else
    func resolve<Service: Sendable>(
        _ service: Service.Type,
        actorID: ActorAddress,
        actorSystem: WebActorSystem
    ) throws -> Service {
        guard let resolve = resolveValue else {
            throw SwiftWebActorBindingError.missingResolver(contract: contract.rawValue)
        }
        return try cast(try resolve(actorID, actorSystem), to: service)
    }
    #endif

    private func cast<Service: Sendable>(
        _ value: any Sendable,
        to service: Service.Type
    ) throws -> Service {
        guard let service = value as? Service else {
            #if hasFeature(Embedded)
            // Embedded Swift has no type reflection; the contract still
            // identifies the failing resolution.
            throw SwiftWebActorBindingError.typeMismatch(
                contract: contract.rawValue,
                expected: "service",
                actual: "resolved value"
            )
            #else
            throw SwiftWebActorBindingError.typeMismatch(
                contract: contract.rawValue,
                expected: String(reflecting: Service.self),
                actual: String(reflecting: Swift.type(of: value))
            )
            #endif
        }
        return service
    }
}

public struct SwiftWebActorResolverRegistry: Sendable {
    private typealias Installer = @Sendable (WebActorSystem) throws -> Void

    private let resolvers: [String: SwiftWebActorResolver]
    private let installers: [Installer]

    public init(_ resolvers: [SwiftWebActorResolver] = []) {
        self.init(resolvers: resolvers, installers: [])
    }

    #if SWIFTWEB_ACTORS
    public init<Bootstrap: SwiftActorSystemBootstrap>(
        _ resolvers: [SwiftWebActorResolver] = [],
        bootstrap: Bootstrap.Type
    ) {
        self.init(
            resolvers: resolvers,
            installers: [
                { actorSystem in
                    try actorSystem.distributedBackend.registerGeneratedBootstrap(
                        bootstrap
                    )
                }
            ]
        )
    }
    #endif

    private init(
        resolvers: [SwiftWebActorResolver],
        installers: [Installer]
    ) {
        var indexed: [String: SwiftWebActorResolver] = [:]
        for resolver in resolvers {
            indexed[resolver.contract.rawValue] = resolver
        }
        self.resolvers = indexed
        self.installers = installers
    }

    public static let empty = SwiftWebActorResolverRegistry()

    public func registering(_ resolver: SwiftWebActorResolver) -> SwiftWebActorResolverRegistry {
        var next = resolvers
        next[resolver.contract.rawValue] = resolver
        return SwiftWebActorResolverRegistry(
            resolvers: Array(next.values),
            installers: installers
        )
    }

    public func resolver(for contract: SwiftWebActorContractKey) throws -> SwiftWebActorResolver {
        guard let resolver = resolvers[contract.rawValue] else {
            throw SwiftWebActorBindingError.missingResolver(contract: contract.rawValue)
        }
        return resolver
    }

    public func install(in actorSystem: WebActorSystem) throws {
        for install in installers {
            try install(actorSystem)
        }
    }
}

public struct SwiftWebActorBindingScope: Sendable {
    private let bindings: [String: SwiftWebActorBindingRecord]
    private let resolverRegistry: SwiftWebActorResolverRegistry
    private let actorSystems: [String: WebActorSystem]
    #if SWIFTWEB_LEGACY_ACTORS
    private let legacyActorSystems: [String: LegacyWebActorSystem]
    #endif
    public let actorSystem: WebActorSystem
    #if SWIFTWEB_LEGACY_ACTORS
    public let legacyActorSystem: LegacyWebActorSystem
    #endif

    #if SWIFTWEB_LEGACY_ACTORS
    public init(
        records: [SwiftWebActorBindingRecord] = [],
        resolverRegistry: SwiftWebActorResolverRegistry = .empty,
        actorSystem: WebActorSystem = .shared,
        legacyActorSystem: LegacyWebActorSystem = .shared
    ) {
        var indexed: [String: SwiftWebActorBindingRecord] = [:]
        for record in records {
            indexed[record.contractKey] = record
        }
        self.init(
            bindings: indexed,
            resolverRegistry: resolverRegistry,
            actorSystem: actorSystem,
            legacyActorSystem: legacyActorSystem,
            actorSystems: Dictionary(
                uniqueKeysWithValues: indexed.keys.map { key in
                    (key, actorSystem)
                }
            ),
            legacyActorSystems: Dictionary(
                uniqueKeysWithValues: indexed.keys.map { key in
                    (key, legacyActorSystem)
                }
            )
        )
    }
    #else
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
    #endif

    #if SWIFTWEB_LEGACY_ACTORS
    private init(
        bindings: [String: SwiftWebActorBindingRecord],
        resolverRegistry: SwiftWebActorResolverRegistry,
        actorSystem: WebActorSystem,
        legacyActorSystem: LegacyWebActorSystem,
        actorSystems: [String: WebActorSystem],
        legacyActorSystems: [String: LegacyWebActorSystem]
    ) {
        self.bindings = bindings
        self.resolverRegistry = resolverRegistry
        self.actorSystem = actorSystem
        self.legacyActorSystem = legacyActorSystem
        self.actorSystems = actorSystems
        self.legacyActorSystems = legacyActorSystems
    }
    #else
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
    #endif

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
        #if SWIFTWEB_LEGACY_ACTORS
        let legacySystem = legacyActorSystems[contract.rawValue] ?? legacyActorSystem
        return try resolver.resolve(
            service,
            actorID: binding.actorID,
            actorSystem: system,
            legacyActorSystem: legacySystem
        )
        #else
        return try resolver.resolve(
            service,
            actorID: binding.actorID,
            actorSystem: system
        )
        #endif
    }

    public func adding<ActorType: ActorSystemReference>(
        _ actor: ActorType
    ) -> SwiftWebActorBindingScope where ActorType.ActorSystem == WebActorSystem {
        let contract = SwiftWebActorContractKey(ActorType.self)
        var records = bindings
        records[contract.rawValue] = SwiftWebActorBindingRecord(
            contract: contract,
            actorID: actor.id
        )
        let registry = resolverRegistry.registering(
            SwiftWebActorResolver(
                contract: contract,
                actorContract: ActorType.self
            )
        )
        var systems = actorSystems
        systems[contract.rawValue] = actor.actorSystem
        #if SWIFTWEB_LEGACY_ACTORS
        return SwiftWebActorBindingScope(
            bindings: records,
            resolverRegistry: registry,
            actorSystem: actorSystem,
            legacyActorSystem: legacyActorSystem,
            actorSystems: systems,
            legacyActorSystems: legacyActorSystems
        )
        #else
        return SwiftWebActorBindingScope(
            bindings: records,
            resolverRegistry: registry,
            actorSystem: actorSystem,
            actorSystems: systems
        )
        #endif
    }

    #if SWIFTWEB_LEGACY_ACTORS
    @available(*, deprecated, message: "Use a concrete actor conforming to ActorSystemReference")
    public func adding<ActorType: LegacySwiftWebActorExporting>(
        _ actor: ActorType
    ) -> SwiftWebActorBindingScope {
        let contract = ActorType.swiftWebActorContractKey
        var records = bindings
        records[contract.rawValue] = SwiftWebActorBindingRecord(
            contract: contract,
            actorID: legacyActorAddress(contract: contract, actorID: actor.id)
        )
        let registry = resolverRegistry.registering(
            SwiftWebActorResolver(
                legacyContract: contract,
                actorContract: ActorType.SwiftWebActorContract.self
            )
        )
        var systems = legacyActorSystems
        systems[contract.rawValue] = actor.actorSystem
        return SwiftWebActorBindingScope(
            bindings: records,
            resolverRegistry: registry,
            actorSystem: actorSystem,
            legacyActorSystem: legacyActorSystem,
            actorSystems: actorSystems,
            legacyActorSystems: systems
        )
    }
    #endif
}

public enum SwiftWebActorBindingContext {
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
}

public enum SwiftWebActorBinding {
    public static func resolve<Service: Sendable>(
        _ service: Service.Type,
        contract: SwiftWebActorContractKey
    ) -> Service {
        guard let scope = SwiftWebActorBindingContext.current else {
            preconditionFailure("@RemoteActor was accessed outside a SwiftWeb actor binding context")
        }
        do {
            return try scope.resolve(service, contract: contract)
        } catch {
            #if hasFeature(Embedded)
            preconditionFailure("@RemoteActor failed to resolve \(contract.rawValue)")
            #else
            preconditionFailure("@RemoteActor failed to resolve \(String(reflecting: Service.self)): \(error)")
            #endif
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

#if !hasFeature(Embedded)
extension SwiftWebActorContractKey: Codable {}
#endif

#if !hasFeature(Embedded)
extension SwiftWebActorBindingRecord: Codable {
    private enum CodingKeys: String, CodingKey {
        case contractKey
        case actorID
        case actorTypeHigh
        case actorTypeLow
        case actorIdentity
    }

    public init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let contractKey = try container.decode(String.self, forKey: .contractKey)
        #if SWIFTWEB_LEGACY_ACTORS
        if let actorID = try container.decodeIfPresent(String.self, forKey: .actorID) {
            self.init(
                contractKey: contractKey,
                actorID: legacyActorAddress(
                    contract: SwiftWebActorContractKey(contractKey),
                    actorID: actorID
                )
            )
            return
        }
        #endif
        self.init(
            contractKey: contractKey,
            actorID: ActorAddress(
                type: ActorTypeID(
                    high: try container.decode(UInt64.self, forKey: .actorTypeHigh),
                    low: try container.decode(UInt64.self, forKey: .actorTypeLow)
                ),
                identity: try container.decode(String.self, forKey: .actorIdentity)
            )
        )
    }

    public func encode(to encoder: any Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(contractKey, forKey: .contractKey)
        try container.encode(actorID.type.high, forKey: .actorTypeHigh)
        try container.encode(actorID.type.low, forKey: .actorTypeLow)
        try container.encode(actorID.identity, forKey: .actorIdentity)
    }
}
#endif

#if SWIFTWEB_LEGACY_ACTORS
private func legacyActorAddress(
    contract: SwiftWebActorContractKey,
    actorID: String
) -> ActorAddress {
    var high: UInt64 = 14_695_981_039_346_656_037
    var low: UInt64 = 1_099_511_628_211
    for byte in contract.rawValue.utf8 {
        high = (high ^ UInt64(byte)) &* 1_099_511_628_211
        low = (low ^ (UInt64(byte) &+ 0x9D)) &* 1_099_511_628_211
    }
    if high == 0, low == 0 {
        low = 1
    }
    return ActorAddress(
        type: ActorTypeID(high: high, low: low),
        identity: actorID
    )
}
#endif
