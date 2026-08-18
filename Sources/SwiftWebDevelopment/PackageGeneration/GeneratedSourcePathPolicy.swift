enum GeneratedSourcePathPolicy {
  static func isServerOnly(relativePath: String) -> Bool {
    let firstComponent = relativePath.split(separator: "/", maxSplits: 1).first.map(String.init)
    if firstComponent == "Actions" || firstComponent == "Routes" {
      return true
    }
    if firstComponent == "ActorSystemGenerated" {
      return true
    }
    return relativePath == "App.swift"
  }

  static func isServerOnlyActorDependency(relativePath: String) -> Bool {
    isServerOnly(relativePath: relativePath)
  }
}
