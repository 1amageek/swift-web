enum GeneratedSourcePathPolicy {
  static func isServerOnly(relativePath: String) -> Bool {
    let firstComponent = relativePath.split(separator: "/", maxSplits: 1).first.map(String.init)
    if firstComponent == "Actions" || firstComponent == "Routes" {
      return true
    }
    return relativePath == "App.swift"
  }
}
