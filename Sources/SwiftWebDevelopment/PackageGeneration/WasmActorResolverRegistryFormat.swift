struct WasmActorResolverRegistryFormat {
  func resolverRegistrySwift(context: GeneratedPackageRenderContext) -> String {
    let functions = context.wasmRuntimeTargets.map { target in
      let actorResolvers = target.actorContracts.map { contract in
        """
                SwiftWebActorResolver(
                    contract: \(contract.contractKeyExpression),
                    actorContract: \(contract.stubTypeName).self
                )
        """
      }
      .joined(separator: ",\n")
      return """
          public static func \(Self.functionName(for: target.targetName))()
              -> SwiftWebActorResolverRegistry
          {
              SwiftWebActorResolverRegistry([
      \(actorResolvers)
              ])
          }
      """
    }
    .joined(separator: "\n\n")
    return """
      import SwiftWebActors

      public enum SwiftWebGeneratedActorResolvers {
      \(functions)
      }
      """
  }

  static func functionName(for targetName: String) -> String {
    GeneratedPackageNameFormatter.lowerCamelCase(targetName)
  }
}
