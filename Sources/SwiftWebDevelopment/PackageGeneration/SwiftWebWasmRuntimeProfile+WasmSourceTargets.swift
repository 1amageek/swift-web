import SwiftWebWasmBuild

extension SwiftWebWasmRuntimeProfile {
  func wasmSourceTargets(appProductName: String) -> [String] {
    [
      appProductName,
      "_CJavaScriptKit",
      "JavaScriptKit",
      "SwiftHTML",
      "SwiftWebActors",
      "SwiftWebStyle",
      "SwiftWebUITheme",
      "SwiftWebUI",
      "SwiftWebUIRuntime",
    ]
  }
}
