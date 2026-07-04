import Foundation
import SwiftHTML
import SwiftWebDevelopmentHooks

enum GeneratedPackageNameFormatter {
  static func productName(forWasmRuntimeTarget targetName: String) -> String {
    kebabCase(targetName)
  }

  static func assetPath(forWasmRuntimeTarget targetName: String) -> String {
    "/assets/\(productName(forWasmRuntimeTarget: targetName)).wasm"
  }

  static func wasmRuntimeTargetName(forClientComponent componentTypeName: String) -> String {
    if componentTypeName.hasPrefix("Client") {
      let suffix = componentTypeName.dropFirst("Client".count)
      if !suffix.isEmpty {
        return "\(suffix)WasmRuntime"
      }
    }
    if componentTypeName.hasSuffix("Component") {
      return "\(componentTypeName.dropLast("Component".count))WasmRuntime"
    }
    return "\(componentTypeName)WasmRuntime"
  }

  static func wasmRuntimeTargetName(forBundleID bundleID: ClientBundleID) -> String {
    let parts = bundleID.rawValue
      .split(separator: "-")
      .map { part in
        part.prefix(1).uppercased() + part.dropFirst()
      }
      .joined()
    return "\(parts)WasmRuntime"
  }

  static func wasmRuntimeTargetSuffix(for loadPolicy: LoadPolicy) -> String {
    switch loadPolicy {
    case .eager:
      return ""
    case .visible:
      return "Visible"
    case .interaction:
      return "Interaction"
    case .idle:
      return "Idle"
    case .manual:
      return "Manual"
    }
  }

  static func variableName(for targetName: String) -> String {
    let first = targetName.prefix(1).lowercased()
    let rest = targetName.dropFirst()
    return "\(first)\(rest)Target"
  }

  static func kebabCase(_ value: String) -> String {
    var output = ""
    for scalar in value.unicodeScalars {
      let character = Character(scalar)
      if CharacterSet.uppercaseLetters.contains(scalar) {
        if !output.isEmpty {
          output.append("-")
        }
        output.append(String(character).lowercased())
      } else {
        output.append(String(character))
      }
    }
    return output
  }

  static func stableBundleName(_ value: String) -> String {
    let allowed = value.unicodeScalars.map { scalar -> Character in
      if CharacterSet.alphanumerics.contains(scalar)
        || scalar.value == 45
        || scalar.value == 95
      {
        return Character(scalar)
      }
      return "-"
    }
    let rawName = String(allowed)
      .split(separator: "-")
      .joined(separator: "-")
      .lowercased()
    guard !rawName.isEmpty else {
      return stableHashHex(value)
    }
    return rawName
  }

  static func stableHashHex(_ value: String) -> String {
    var hash: UInt64 = 14_695_981_039_346_656_037
    for byte in value.utf8 {
      hash ^= UInt64(byte)
      hash &*= 1_099_511_628_211
    }
    return String(hash, radix: 16)
  }

  static func localPackageIdentity(for packageDirectory: URL) -> String {
    packageDirectory
      .lastPathComponent
      .lowercased()
  }

  static func swiftStringLiteral(_ value: String) -> String {
    value
      .replacingOccurrences(of: "\\", with: "\\\\")
      .replacingOccurrences(of: "\"", with: "\\\"")
      .replacingOccurrences(of: "\n", with: "\\n")
      .replacingOccurrences(of: "\r", with: "\\r")
  }

  static func relativePath(from baseDirectory: URL, to targetDirectory: URL) -> String {
    let baseComponents = baseDirectory.standardizedFileURL.pathComponents
    let targetComponents = targetDirectory.standardizedFileURL.pathComponents
    var commonCount = 0

    while commonCount < baseComponents.count,
      commonCount < targetComponents.count,
      baseComponents[commonCount] == targetComponents[commonCount]
    {
      commonCount += 1
    }

    let parents = Array(repeating: "..", count: baseComponents.count - commonCount)
    let children = Array(targetComponents.dropFirst(commonCount))
    let components = parents + children
    return components.isEmpty ? "." : components.joined(separator: "/")
  }

  static func uniqueTypeNames(_ typeNames: [String]) -> [String] {
    var seen = Set<String>()
    var unique: [String] = []
    for typeName in typeNames where seen.insert(typeName).inserted {
      unique.append(typeName)
    }
    return unique
  }

  static func actorContracts(
    for components: [ClientComponentDeclaration]
  ) -> [ClientActorContractDeclaration] {
    var seen = Set<String>()
    var unique: [ClientActorContractDeclaration] = []
    for declaration in components
      .flatMap(\.actorContracts)
      .sorted(by: { $0.serviceTypeName < $1.serviceTypeName })
    where seen.insert(declaration.serviceTypeName).inserted {
      unique.append(declaration)
    }
    return unique
  }

  static func lowerCamelCase(_ value: String) -> String {
    guard let first = value.first else {
      return value
    }
    return first.lowercased() + String(value.dropFirst())
  }
}
