import SwiftWebWasmBuild

extension SwiftWebWasmRuntimeProfile {
  func wasmSourceTargets(appProductName: String) -> [String] {
    let actorRuntimeTarget = switch self {
    case .standard:
      "ActorSystemDistributed"
    case .embedded:
      "ActorSystemEmbedded"
    }
    return [
      appProductName,
      "_CJavaScriptKit",
      "JavaScriptKit",
      "_CJavaScriptEventLoop",
      "JavaScriptEventLoop",
      "ActorSystemCore",
      actorRuntimeTarget,
      "SwiftHTML",
      "SwiftWebActors",
      "SwiftWebStyle",
      "SwiftWebUITheme",
      "SwiftWebUI",
      "SwiftWebUIRuntime",
    ]
  }
}
