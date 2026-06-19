import Foundation
import SwiftHTML
import SwiftWebDevelopmentHooks

extension SwiftWebDevClientManifestSnapshotStore {
  func schemaHashes(for runtime: SwiftWebGeneratedWasmRuntime) throws
    -> SwiftWebDevClientManifestSchemaHashes
  {
    guard let manifest = try read() else {
      return .empty
    }

    let components = manifest.components.filter { component in
      component.bundleID == runtime.bundleID
        || runtime.componentTypeNames.contains { typeName in
          Self.typeNamesMatch(typeName, component.typeName)
        }
    }
    guard !components.isEmpty else {
      return .empty
    }

    return SwiftWebDevClientManifestSchemaHashes(
      stateSchemaHash: Self.combinedHash(
        components.map(\.stateSchemaHash),
        empty: StateSchema.hash([])
      ),
      environmentSchemaHash: Self.combinedHash(
        components.map(\.environmentSchemaHash),
        empty: ClientEnvironmentSnapshot().schemaHash
      )
    )
  }

  private static func typeNamesMatch(_ left: String, _ right: String) -> Bool {
    left == right || left.hasSuffix(".\(right)") || right.hasSuffix(".\(left)")
  }

  private static func combinedHash(_ hashes: [String], empty: String) -> String {
    let unique = Array(Set(hashes.filter { !$0.isEmpty })).sorted()
    guard !unique.isEmpty else {
      return empty
    }
    guard unique.count > 1 else {
      return unique[0]
    }
    return stableHash(unique.joined(separator: "\n"))
  }

  private static func stableHash(_ value: String) -> String {
    var hash: UInt64 = 0xcbf29ce484222325
    for byte in value.utf8 {
      hash ^= UInt64(byte)
      hash &*= 0x100000001b3
    }
    return String(format: "%016llx", hash)
  }
}
