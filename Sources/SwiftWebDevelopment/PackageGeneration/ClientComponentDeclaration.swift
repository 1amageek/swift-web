import SwiftWebDevelopmentHooks
import SwiftWebWasmBuild
import SwiftHTML

struct ClientComponentDeclaration: Sendable {
    let typeName: String
    var loadPolicy: LoadPolicy
    var bundlePolicy: BundlePolicy
    var actorContracts: [ClientActorContractDeclaration]

    init(
        typeName: String,
        loadPolicy: LoadPolicy = .eager,
        bundlePolicy: BundlePolicy = .main,
        actorContracts: [ClientActorContractDeclaration] = []
    ) {
        self.typeName = typeName
        self.loadPolicy = loadPolicy
        self.bundlePolicy = bundlePolicy
        self.actorContracts = Self.uniqueActorContracts(actorContracts)
    }

    var identityKey: String {
        "\(typeName)|\(loadPolicy.rawValue)|\(bundleIdentity)"
    }

    func merged(with other: ClientComponentDeclaration) -> ClientComponentDeclaration {
        ClientComponentDeclaration(
            typeName: typeName,
            loadPolicy: other.loadPolicy != .eager ? other.loadPolicy : loadPolicy,
            bundlePolicy: other.bundlePolicy != .main ? other.bundlePolicy : bundlePolicy,
            actorContracts: actorContracts + other.actorContracts
        )
    }

    private static func uniqueActorContracts(
        _ declarations: [ClientActorContractDeclaration]
    ) -> [ClientActorContractDeclaration] {
        var seen = Set<String>()
        var unique: [ClientActorContractDeclaration] = []
        for declaration in declarations.sorted(by: { $0.serviceTypeName < $1.serviceTypeName })
        where seen.insert(declaration.serviceTypeName).inserted {
            unique.append(declaration)
        }
        return unique
    }

    private var bundleIdentity: String {
        switch bundlePolicy {
        case .main:
            return "main"
        case .component:
            return "component"
        case .named(let name):
            return "named:\(name)"
        case .shared(let name):
            return "shared:\(name)"
        }
    }
}

struct ClientActorContractDeclaration: Sendable, Hashable {
    let serviceTypeName: String

    init(serviceTypeName: String) {
        self.serviceTypeName = serviceTypeName
    }

    var existentialTypeName: String {
        "any \(serviceTypeName)"
    }

    var stubTypeName: String {
        let components = serviceTypeName.split(separator: ".").map(String.init)
        guard let last = components.last else {
            return "$\(serviceTypeName)"
        }
        let prefix = components.dropLast().joined(separator: ".")
        if prefix.isEmpty {
            return "$\(last)"
        }
        return "\(prefix).$\(last)"
    }

    var contractKeyExpression: String {
        "SwiftWebActorContractKey(String(reflecting: (\(existentialTypeName)).self))"
    }
}
