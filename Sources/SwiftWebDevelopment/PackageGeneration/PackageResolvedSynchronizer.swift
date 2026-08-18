import Foundation

struct PackageResolvedSynchronizer: Sendable {
  struct Snapshot: Sendable {
    let sourceURL: URL
    let data: Data
  }

  let appPackageDirectory: URL
  let fileWriter: GeneratedPackageFileWriter

  func snapshot(fallbackPackageDirectory: URL? = nil) throws -> Snapshot? {
    guard let sourceURL = packageResolvedSourceURL(
      fallbackPackageDirectory: fallbackPackageDirectory
    ) else {
      return nil
    }
    return Snapshot(sourceURL: sourceURL, data: try Data(contentsOf: sourceURL))
  }

  func sync(
    _ snapshot: Snapshot?,
    to packageDirectory: URL,
    keepingIdentities identities: Set<String>? = nil
  ) throws {
    let destinationURL = packageDirectory.appendingPathComponent("Package.resolved")

    if let snapshot {
      if let identities {
        let data = try filteredPackageResolvedData(
          snapshot,
          keepingIdentities: identities
        )
        try fileWriter.writeDataIfChanged(data, to: destinationURL)
      } else {
        try fileWriter.writeDataIfChanged(snapshot.data, to: destinationURL)
      }
    } else if FileManager.default.fileExists(atPath: destinationURL.path) {
      try FileManager.default.removeItem(at: destinationURL)
    }
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

  private func filteredPackageResolvedData(
    _ snapshot: Snapshot,
    keepingIdentities identities: Set<String>
  ) throws -> Data {
    guard let object = try JSONSerialization.jsonObject(with: snapshot.data)
      as? [String: Any]
    else {
      throw SwiftWebGeneratedPackageMaterializerError.invalidPackageResolved(
        snapshot.sourceURL
      )
    }
    guard let pins = object["pins"] as? [[String: Any]] else {
      throw SwiftWebGeneratedPackageMaterializerError.invalidPackageResolved(
        snapshot.sourceURL
      )
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
