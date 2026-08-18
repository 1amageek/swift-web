struct WasmPackageFormat: GeneratedPackageFormat {
  let packageKind = GeneratedPackageKind.wasm

  private let manifestFormat = WasmPackageManifestFormat()
  private let entrypointFormat = WasmRuntimeEntrypointFormat()
  private let actorResolverFormat = WasmActorResolverRegistryFormat()

  func files(context: GeneratedPackageRenderContext) throws -> [GeneratedFile] {
    var files = context.wasmRuntimeTargets.map { target in
      GeneratedFile(
        packageKind: packageKind,
        relativePath: "Sources/\(target.targetName)/\(target.targetName).swift",
        contents: entrypointFormat.entrypointSwift(context: context, target: target)
      )
    }
    files.append(
      GeneratedFile(
        packageKind: packageKind,
        relativePath: "Sources/\(context.appProductName)/SwiftWebGeneratedActorResolvers.swift",
        contents: try actorResolverFormat.resolverRegistrySwift(context: context)
      ))
    files.append(
      GeneratedFile(
        packageKind: packageKind,
        relativePath: "Package.swift",
        contents: try manifestFormat.packageSwift(context: context)
      )
    )
    return files
  }
}
