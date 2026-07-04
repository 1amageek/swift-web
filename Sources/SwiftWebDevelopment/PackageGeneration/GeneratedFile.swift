struct GeneratedFile: Sendable {
  let packageKind: GeneratedPackageKind
  let relativePath: String
  let contents: String

  init(
    packageKind: GeneratedPackageKind,
    relativePath: String,
    contents: String
  ) {
    self.packageKind = packageKind
    self.relativePath = relativePath
    self.contents = contents
  }
}
