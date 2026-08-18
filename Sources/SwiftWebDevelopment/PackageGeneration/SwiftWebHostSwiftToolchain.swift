import SwiftWebWasmBuild
import Foundation
import SwiftWebDevelopmentHooks

package struct SwiftWebHostSwiftToolchain: Sendable {
  package let swiftExecutableURL: URL
  package let binDirectory: URL

  package var swiftCompilerURL: URL {
    binDirectory.appendingPathComponent("swiftc").standardizedFileURL
  }

  package static func resolve(
    configuration: SwiftWebDevRuntimeConfiguration,
    environment: [String: String] = ProcessInfo.processInfo.environment
  ) throws -> SwiftWebHostSwiftToolchain {
    let fileManager = FileManager.default
    var searched: [String] = []

    if let explicitURL = configuration.hostSwiftExecutableURL {
      searched.append(explicitURL.path)
      guard fileManager.isExecutableFile(atPath: explicitURL.path) else {
        throw SwiftWebHostToolchainError.hostSwiftToolchainNotFound(searched: searched)
      }
      try SwiftWebPinnedToolchain.validate(swiftExecutableURL: explicitURL)
      return SwiftWebHostSwiftToolchain(
        swiftExecutableURL: explicitURL,
        binDirectory: explicitURL.deletingLastPathComponent()
      )
    }

    if let override = environment["SWIFT_WEB_HOST_SWIFT"], !override.isEmpty {
      let swiftURL = URL(fileURLWithPath: override).standardizedFileURL
      searched.append(swiftURL.path)
      guard fileManager.isExecutableFile(atPath: swiftURL.path) else {
        throw SwiftWebHostToolchainError.hostSwiftToolchainNotFound(searched: searched)
      }
      try SwiftWebPinnedToolchain.validate(swiftExecutableURL: swiftURL)
      return SwiftWebHostSwiftToolchain(
        swiftExecutableURL: swiftURL,
        binDirectory: swiftURL.deletingLastPathComponent()
      )
    }

    if let binOverride = environment["SWIFT_WEB_HOST_TOOLCHAIN_BIN"], !binOverride.isEmpty {
      let binURL = URL(fileURLWithPath: binOverride).standardizedFileURL
      if let toolchain = try requiredToolchain(
        binDirectory: binURL,
        searched: &searched,
        fileManager: fileManager
      ) {
        return toolchain
      }
      throw SwiftWebHostToolchainError.hostSwiftToolchainNotFound(searched: searched)
    }

    let pinnedBinURL = fileManager.homeDirectoryForCurrentUser
      .appendingPathComponent("Library/Developer/Toolchains", isDirectory: true)
      .appendingPathComponent(
        "\(SwiftWebPinnedToolchain.snapshotTag).xctoolchain/usr/bin",
        isDirectory: true
      )
      .standardizedFileURL
    if let toolchain = validatedToolchain(
      binDirectory: pinnedBinURL,
      searched: &searched,
      fileManager: fileManager
    ) {
      return toolchain
    }

    if let xcrunSwiftURL = findXcrunSwift(searched: &searched, fileManager: fileManager),
      let toolchain = validatedToolchain(
        swiftExecutableURL: xcrunSwiftURL,
        searched: &searched,
        fileManager: fileManager
      ) {
      return toolchain
    }

    for directory in (environment["PATH"] ?? "").split(separator: ":") {
      let binURL = URL(fileURLWithPath: String(directory)).standardizedFileURL
      if let toolchain = validatedToolchain(
        binDirectory: binURL,
        searched: &searched,
        fileManager: fileManager
      ) {
        return toolchain
      }
    }

    throw SwiftWebHostToolchainError.hostSwiftToolchainNotFound(searched: searched)
  }

  package func applying(to environment: [String: String]) -> [String: String] {
    var result = environment
    let currentPath = result["PATH"] ?? ""
    result["PATH"] = "\(binDirectory.path):\(currentPath)"
    return result
  }

  private static func requiredToolchain(
    binDirectory: URL,
    searched: inout [String],
    fileManager: FileManager
  ) throws -> SwiftWebHostSwiftToolchain? {
    let swiftURL = binDirectory.appendingPathComponent("swift").standardizedFileURL
    searched.append(swiftURL.path)
    guard fileManager.isExecutableFile(atPath: swiftURL.path) else {
      return nil
    }
    try SwiftWebPinnedToolchain.validate(swiftExecutableURL: swiftURL)
    return SwiftWebHostSwiftToolchain(
      swiftExecutableURL: swiftURL,
      binDirectory: binDirectory
    )
  }

  private static func validatedToolchain(
    binDirectory: URL,
    searched: inout [String],
    fileManager: FileManager
  ) -> SwiftWebHostSwiftToolchain? {
    validatedToolchain(
      swiftExecutableURL: binDirectory.appendingPathComponent("swift").standardizedFileURL,
      searched: &searched,
      fileManager: fileManager
    )
  }

  private static func validatedToolchain(
    swiftExecutableURL: URL,
    searched: inout [String],
    fileManager: FileManager
  ) -> SwiftWebHostSwiftToolchain? {
    searched.append(swiftExecutableURL.path)
    guard fileManager.isExecutableFile(atPath: swiftExecutableURL.path) else {
      return nil
    }
    do {
      try SwiftWebPinnedToolchain.validate(swiftExecutableURL: swiftExecutableURL)
    } catch {
      searched.append("\(swiftExecutableURL.path) rejected: \(error)")
      return nil
    }
    return SwiftWebHostSwiftToolchain(
      swiftExecutableURL: swiftExecutableURL,
      binDirectory: swiftExecutableURL.deletingLastPathComponent()
    )
  }

  private static func findXcrunSwift(
    searched: inout [String],
    fileManager: FileManager
  ) -> URL? {
    let xcrunURL = URL(fileURLWithPath: "/usr/bin/xcrun")
    searched.append("\(xcrunURL.path) --find swift")
    guard fileManager.isExecutableFile(atPath: xcrunURL.path) else {
      return nil
    }

    let process = Process()
    let output = Pipe()
    process.executableURL = xcrunURL
    process.arguments = ["--find", "swift"]
    process.standardOutput = output
    process.standardError = FileHandle.standardError

    do {
      try process.run()
    } catch {
      return nil
    }

    let data = output.fileHandleForReading.readDataToEndOfFile()
    process.waitUntilExit()
    guard process.terminationStatus == 0 else {
      return nil
    }

    let path = String(decoding: data, as: UTF8.self)
      .trimmingCharacters(in: Foundation.CharacterSet.whitespacesAndNewlines)
    guard !path.isEmpty else {
      return nil
    }

    let swiftURL = URL(fileURLWithPath: path).standardizedFileURL
    searched.append(swiftURL.path)
    guard fileManager.isExecutableFile(atPath: swiftURL.path) else {
      return nil
    }
    return swiftURL
  }
}
