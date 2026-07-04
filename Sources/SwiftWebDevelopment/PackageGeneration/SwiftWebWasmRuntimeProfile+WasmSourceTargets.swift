import SwiftWebWasmBuild

extension SwiftWebWasmRuntimeProfile {
  func wasmSourceTargets(appProductName: String) -> [String] {
    switch self {
    case .standard:
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
    case .embedded:
      [
        "_CJavaScriptKit",
        "JavaScriptKit",
        "SwiftHTMLClientRuntime",
      ]
    }
  }
}
