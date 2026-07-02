import SwiftWebDevelopmentHooks
import SwiftWebPackageGeneration
import SwiftWebWasmBuild
import Foundation

package enum SwiftWebDevWasmScratchDirectory {
  package static func resolve(from serverScratchDirectory: URL?) -> URL? {
    guard let serverScratchDirectory else {
      return nil
    }

    let standardizedServerScratchDirectory = serverScratchDirectory.standardizedFileURL
    let parent = standardizedServerScratchDirectory.deletingLastPathComponent()
    if parent.lastPathComponent == ".build" {
      return parent
        .deletingLastPathComponent()
        .appendingPathComponent("wasm-build", isDirectory: true)
        .appendingPathComponent(standardizedServerScratchDirectory.lastPathComponent, isDirectory: true)
        .standardizedFileURL
    }

    let name = "\(standardizedServerScratchDirectory.lastPathComponent)-wasm"
    return parent
      .appendingPathComponent(name, isDirectory: true)
      .standardizedFileURL
  }
}
