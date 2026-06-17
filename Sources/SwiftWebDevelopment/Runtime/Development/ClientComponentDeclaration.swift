import SwiftHTML

struct ClientComponentDeclaration: Sendable {
    let typeName: String
    var loadPolicy: LoadPolicy
    var bundlePolicy: BundlePolicy

    init(
        typeName: String,
        loadPolicy: LoadPolicy = .eager,
        bundlePolicy: BundlePolicy = .main
    ) {
        self.typeName = typeName
        self.loadPolicy = loadPolicy
        self.bundlePolicy = bundlePolicy
    }

    var identityKey: String {
        "\(typeName)|\(loadPolicy.rawValue)|\(bundleIdentity)"
    }

    func merged(with other: ClientComponentDeclaration) -> ClientComponentDeclaration {
        ClientComponentDeclaration(
            typeName: typeName,
            loadPolicy: other.loadPolicy != .eager ? other.loadPolicy : loadPolicy,
            bundlePolicy: other.bundlePolicy != .main ? other.bundlePolicy : bundlePolicy
        )
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
