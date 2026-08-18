struct WasmActorResolverRegistryFormat {
  func resolverRegistrySwift(context: GeneratedPackageRenderContext) throws -> String {
    let legacyContracts = context.wasmRuntimeTargets
      .flatMap(\.actorContracts)
      .filter(\.isLegacyExistential)
      .map(\.serviceTypeName)
    guard legacyContracts.isEmpty else {
      throw SwiftWebGeneratedPackageMaterializerError.legacyActorContractsUnsupported(
        profile: context.wasmRuntimeProfile,
        contracts: Array(Set(legacyContracts)).sorted()
      )
    }
    let dependencyBootstrapTypeNames = context.actorDependencyTargets.compactMap { target in
      target.bootstrapTypeName.map { "\(target.moduleName).\($0)" }
    }
    let bootstrapTypeNames = ([context.clientActorBootstrapTypeName].compactMap { $0 }
      + dependencyBootstrapTypeNames)
      .reduce(into: [String]()) { names, name in
        if !names.contains(name) {
          names.append(name)
        }
      }
    let usesAggregateBootstrap = context.wasmRuntimeProfile == .standard
      && !bootstrapTypeNames.isEmpty
    let runtimeImports = usesAggregateBootstrap
      ? ["ActorSystemCore", "ActorSystemDistributed"]
      : []
    let imports = (runtimeImports + ["SwiftWebActors"]
      + context.actorDependencyTargets.map(\.moduleName))
      .map { "import \($0)" }
      .joined(separator: "\n")
    let aggregateBootstrap: String
    if usesAggregateBootstrap {
      let dependencies = bootstrapTypeNames
        .map { "        \($0).self," }
        .joined(separator: "\n")
      aggregateBootstrap = """

      private enum SwiftWebGeneratedActorSystemBootstrap: SwiftActorSystemBootstrap {
          static let bootstrapIdentifier = "swiftweb-client:\(context.appPackageName)"
          static let actorTypeDescriptors: [ActorTypeDescriptor] = []
          static let dependencies: [any SwiftActorSystemBootstrap.Type] = [
      \(dependencies)
          ]

          static func register(in actorSystem: SwiftActorSystem) throws {}
      }
      """
    } else {
      aggregateBootstrap = ""
    }
    let functions = context.wasmRuntimeTargets.map { target in
      let actorResolvers = target.actorContracts.map { contract in
        return """
                SwiftWebActorResolver(
                    contract: SwiftWebActorContractKey(\(contract.serviceTypeName).self),
                    actorContract: \(contract.serviceTypeName).self
                )
        """
      }
      .joined(separator: ",\n")
      let bootstrapArgument: String
      if usesAggregateBootstrap {
        bootstrapArgument = ",\n              bootstrap: SwiftWebGeneratedActorSystemBootstrap.self"
      } else {
        bootstrapArgument = ""
      }
      return """
          public static func \(Self.functionName(for: target.targetName))()
              -> SwiftWebActorResolverRegistry
          {
              SwiftWebActorResolverRegistry([
      \(actorResolvers)
              ]\(bootstrapArgument))
          }
      """
    }
    .joined(separator: "\n\n")
    return """
      \(imports)
      \(aggregateBootstrap)

      public enum SwiftWebGeneratedActorResolvers {
      \(functions)
      }
      """
  }

  static func functionName(for targetName: String) -> String {
    GeneratedPackageNameFormatter.lowerCamelCase(targetName)
  }
}
