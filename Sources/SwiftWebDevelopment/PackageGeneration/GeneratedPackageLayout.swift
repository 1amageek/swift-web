import Foundation

struct GeneratedPackageLayout: Sendable {
  let appPackageDirectory: URL
  let rootDirectory: URL

  init(appPackageDirectory: URL, rootDirectory: URL) {
    self.appPackageDirectory = appPackageDirectory.standardizedFileURL
    self.rootDirectory = rootDirectory.standardizedFileURL
  }

  var serverPackageDirectory: URL {
    rootDirectory
      .appendingPathComponent("server", isDirectory: true)
      .standardizedFileURL
  }

  var devPackageDirectory: URL {
    rootDirectory
      .appendingPathComponent("dev", isDirectory: true)
      .standardizedFileURL
  }

  var wasmPackageDirectory: URL {
    rootDirectory
      .appendingPathComponent("wasm", isDirectory: true)
      .standardizedFileURL
  }

  func packageDirectory(for kind: GeneratedPackageKind) -> URL {
    switch kind {
    case .server:
      serverPackageDirectory
    case .dev:
      devPackageDirectory
    case .wasm:
      wasmPackageDirectory
    }
  }
}
