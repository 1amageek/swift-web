protocol GeneratedPackageFormat: Sendable {
  var packageKind: GeneratedPackageKind { get }

  func files(context: GeneratedPackageRenderContext) throws -> [GeneratedFile]
}
