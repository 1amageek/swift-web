import Foundation

struct GeneratedPackageFileWriter: Sendable {
  func removeGeneratedBuildDirectoryIfPackageChanged(
    in packageDirectory: URL,
    nextPackageSwift: String
  ) throws {
    let packageFile = packageDirectory.appendingPathComponent("Package.swift")
    guard FileManager.default.fileExists(atPath: packageFile.path) else {
      return
    }

    let currentPackageSwift = try String(contentsOf: packageFile, encoding: .utf8)
    guard currentPackageSwift != nextPackageSwift else {
      return
    }

    let buildDirectory = packageDirectory.appendingPathComponent(".build", isDirectory: true)
    if FileManager.default.fileExists(atPath: buildDirectory.path) {
      try removeGeneratedItem(at: buildDirectory)
    }
  }

  func write(_ contents: String, to relativePath: String, in packageDirectory: URL) throws {
    let url = packageDirectory.appendingPathComponent(relativePath)
    try FileManager.default.createDirectory(
      at: url.deletingLastPathComponent(),
      withIntermediateDirectories: true
    )
    try writeIfChanged(contents, to: url)
  }

  func writeIfChanged(_ contents: String, to url: URL) throws {
    if FileManager.default.fileExists(atPath: url.path) {
      let current = try String(contentsOf: url, encoding: .utf8)
      if current == contents {
        return
      }
    }
    try contents.write(to: url, atomically: true, encoding: .utf8)
  }

  func writeDataIfChanged(_ data: Data, to url: URL) throws {
    if FileManager.default.fileExists(atPath: url.path) {
      let current = try Data(contentsOf: url)
      if current == data {
        return
      }
    }
    try data.write(to: url, options: [.atomic])
  }

  func copyFileIfChanged(from source: URL, to destination: URL) throws {
    if FileManager.default.fileExists(atPath: destination.path) {
      let sourceData = try Data(contentsOf: source)
      try writeDataIfChanged(sourceData, to: destination)
      return
    }
    try FileManager.default.copyItem(at: source, to: destination)
  }

  func mirrorDirectoryContents(
    from sourceDirectory: URL,
    to destinationDirectory: URL,
    relativePath: String,
    shouldSkip: (String) -> Bool,
    shouldPreserve: (String) -> Bool = { _ in false },
    transform: ((_ relativePath: String, _ data: Data) throws -> Data)? = nil
  ) throws {
    let children = try FileManager.default.contentsOfDirectory(
      at: sourceDirectory,
      includingPropertiesForKeys: [.isDirectoryKey],
      options: [.skipsHiddenFiles]
    )

    var expectedNames = Set<String>()
    for child in children {
      let relativeChildPath =
        relativePath.isEmpty
        ? child.lastPathComponent
        : "\(relativePath)/\(child.lastPathComponent)"
      guard !shouldSkip(relativeChildPath) else {
        continue
      }
      expectedNames.insert(child.lastPathComponent)

      let destination = destinationDirectory.appendingPathComponent(child.lastPathComponent)
      let values = try child.resourceValues(forKeys: [.isDirectoryKey])
      if values.isDirectory == true {
        try FileManager.default.createDirectory(
          at: destination,
          withIntermediateDirectories: true
        )
        try mirrorDirectoryContents(
          from: child,
          to: destination,
          relativePath: relativeChildPath,
          shouldSkip: shouldSkip,
          shouldPreserve: shouldPreserve,
          transform: transform
        )
      } else if let transform {
        let data = try Data(contentsOf: child)
        try writeDataIfChanged(try transform(relativeChildPath, data), to: destination)
      } else {
        try copyFileIfChanged(from: child, to: destination)
      }
    }

    let destinationChildren = try FileManager.default.contentsOfDirectory(
      at: destinationDirectory,
      includingPropertiesForKeys: nil,
      options: [.skipsHiddenFiles]
    )
    for child in destinationChildren {
      let relativeChildPath =
        relativePath.isEmpty
        ? child.lastPathComponent
        : "\(relativePath)/\(child.lastPathComponent)"
      guard !expectedNames.contains(child.lastPathComponent),
        !shouldPreserve(relativeChildPath)
      else {
        continue
      }
      try removeGeneratedItem(at: child)
    }
  }

  func removeGeneratedItem(at url: URL) throws {
    do {
      try FileManager.default.removeItem(at: url)
    } catch {
      try removeGeneratedItemWithRM(at: url, originalError: error)
    }
  }

  private func removeGeneratedItemWithRM(at url: URL, originalError: any Error) throws {
    let process = Process()
    process.executableURL = URL(fileURLWithPath: "/bin/rm")
    process.arguments = ["-rf", url.path]
    process.standardOutput = FileHandle.standardOutput
    process.standardError = FileHandle.standardError

    try process.run()
    process.waitUntilExit()

    if process.terminationStatus != 0 || FileManager.default.fileExists(atPath: url.path) {
      throw originalError
    }
  }
}
