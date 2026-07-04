import Foundation

struct PackageResolvedSynchronizer: Sendable {
  let appPackageDirectory: URL
  let fileWriter: GeneratedPackageFileWriter

  func sync(
    to packageDirectory: URL,
    fallbackPackageDirectory: URL? = nil,
    keepingIdentities identities: Set<String>? = nil
  ) throws {
    let destinationURL = packageDirectory.appendingPathComponent("Package.resolved")

    if let sourceURL = packageResolvedSourceURL(fallbackPackageDirectory: fallbackPackageDirectory)
    {
      if let identities {
        let data = try filteredPackageResolvedData(from: sourceURL, keepingIdentities: identities)
        try fileWriter.writeDataIfChanged(data, to: destinationURL)
      } else {
        let data = try Data(contentsOf: sourceURL)
        try fileWriter.writeDataIfChanged(data, to: destinationURL)
      }
    } else if FileManager.default.fileExists(atPath: destinationURL.path) {
      try FileManager.default.removeItem(at: destinationURL)
    }
  }

  func actorRuntimeDependencyDeclaration(
    fallbackPackageDirectory: URL? = nil
  ) throws -> String {
    guard
      let sourceURL = packageResolvedSourceURL(fallbackPackageDirectory: fallbackPackageDirectory)
    else {
      return fallbackActorRuntimeDependencyDeclaration
    }

    let data = try Data(contentsOf: sourceURL)
    let packageResolved = try JSONDecoder().decode(PackageResolvedFile.self, from: data)
    guard
      let pin = packageResolved.pins.first(where: {
        $0.identity.lowercased() == "swift-actor-runtime"
      })
    else {
      return fallbackActorRuntimeDependencyDeclaration
    }

    let location = pin.location ?? "https://github.com/1amageek/swift-actor-runtime.git"
    if let version = pin.state.version {
      return
        #".package(url: "\#(GeneratedPackageNameFormatter.swiftStringLiteral(location))", exact: "\#(GeneratedPackageNameFormatter.swiftStringLiteral(version))")"#
    }
    if let revision = pin.state.revision {
      return
        #".package(url: "\#(GeneratedPackageNameFormatter.swiftStringLiteral(location))", revision: "\#(GeneratedPackageNameFormatter.swiftStringLiteral(revision))")"#
    }
    return fallbackActorRuntimeDependencyDeclaration
  }

  private func packageResolvedSourceURL(fallbackPackageDirectory: URL?) -> URL? {
    let appPackageResolved = appPackageDirectory.appendingPathComponent("Package.resolved")
    if FileManager.default.fileExists(atPath: appPackageResolved.path) {
      return appPackageResolved
    }

    guard let fallbackPackageDirectory else {
      return nil
    }

    let fallbackPackageResolved = fallbackPackageDirectory.appendingPathComponent(
      "Package.resolved"
    )
    if FileManager.default.fileExists(atPath: fallbackPackageResolved.path) {
      return fallbackPackageResolved
    }

    return nil
  }

  private var fallbackActorRuntimeDependencyDeclaration: String {
    #".package(url: "https://github.com/1amageek/swift-actor-runtime.git", from: "0.6.0")"#
  }

  private func filteredPackageResolvedData(
    from sourceURL: URL,
    keepingIdentities identities: Set<String>
  ) throws -> Data {
    let data = try Data(contentsOf: sourceURL)
    guard let object = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
      throw SwiftWebGeneratedPackageMaterializerError.invalidPackageResolved(sourceURL)
    }
    guard let pins = object["pins"] as? [[String: Any]] else {
      throw SwiftWebGeneratedPackageMaterializerError.invalidPackageResolved(sourceURL)
    }

    let filteredPins = pins.filter { pin in
      guard let identity = pin["identity"] as? String else {
        return false
      }
      return identities.contains(identity.lowercased())
    }
    let filteredObject: [String: Any] = [
      "pins": filteredPins,
      "version": object["version"] ?? 3,
    ]
    return try JSONSerialization.data(
      withJSONObject: filteredObject,
      options: [.prettyPrinted, .sortedKeys]
    )
  }
}

private struct PackageResolvedFile: Decodable {
  let pins: [PackageResolvedPin]
}

private struct PackageResolvedPin: Decodable {
  let identity: String
  let location: String?
  let state: PackageResolvedPinState
}

private struct PackageResolvedPinState: Decodable {
  let version: String?
  let revision: String?
}
