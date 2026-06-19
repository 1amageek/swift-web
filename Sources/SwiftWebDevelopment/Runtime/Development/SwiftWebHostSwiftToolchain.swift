import Foundation
import SwiftWebDevelopmentHooks

struct SwiftWebHostSwiftToolchain: Sendable {
  let swiftExecutableURL: URL
  let binDirectory: URL

  static func resolve(
    configuration: SwiftWebDevRuntimeConfiguration,
    environment: [String: String] = ProcessInfo.processInfo.environment
  ) throws -> SwiftWebHostSwiftToolchain {
    let fileManager = FileManager.default
    var searched: [String] = []

    if let explicitURL = configuration.hostSwiftExecutableURL {
      searched.append(explicitURL.path)
      guard fileManager.isExecutableFile(atPath: explicitURL.path) else {
        throw SwiftWebDevRuntimeError.hostSwiftToolchainNotFound(searched: searched)
      }
      return SwiftWebHostSwiftToolchain(
        swiftExecutableURL: explicitURL,
        binDirectory: explicitURL.deletingLastPathComponent()
      )
    }

    if let override = environment["SWIFT_WEB_HOST_SWIFT"], !override.isEmpty {
      let swiftURL = URL(fileURLWithPath: override).standardizedFileURL
      searched.append(swiftURL.path)
      guard fileManager.isExecutableFile(atPath: swiftURL.path) else {
        throw SwiftWebDevRuntimeError.hostSwiftToolchainNotFound(searched: searched)
      }
      return SwiftWebHostSwiftToolchain(
        swiftExecutableURL: swiftURL,
        binDirectory: swiftURL.deletingLastPathComponent()
      )
    }

    if let binOverride = environment["SWIFT_WEB_HOST_TOOLCHAIN_BIN"], !binOverride.isEmpty {
      let binURL = URL(fileURLWithPath: binOverride).standardizedFileURL
      if let toolchain = toolchain(binDirectory: binURL, searched: &searched, fileManager: fileManager) {
        return toolchain
      }
    }

    if let xcrunSwiftURL = findXcrunSwift(searched: &searched, fileManager: fileManager) {
      return SwiftWebHostSwiftToolchain(
        swiftExecutableURL: xcrunSwiftURL,
        binDirectory: xcrunSwiftURL.deletingLastPathComponent()
      )
    }

    for directory in (environment["PATH"] ?? "").split(separator: ":") {
      let binURL = URL(fileURLWithPath: String(directory)).standardizedFileURL
      if let toolchain = toolchain(binDirectory: binURL, searched: &searched, fileManager: fileManager) {
        return toolchain
      }
    }

    throw SwiftWebDevRuntimeError.hostSwiftToolchainNotFound(searched: searched)
  }

  func applying(to environment: [String: String]) -> [String: String] {
    var result = environment
    let currentPath = result["PATH"] ?? ""
    result["PATH"] = "\(binDirectory.path):\(currentPath)"
    return result
  }

  private static func toolchain(
    binDirectory: URL,
    searched: inout [String],
    fileManager: FileManager
  ) -> SwiftWebHostSwiftToolchain? {
    let swiftURL = binDirectory.appendingPathComponent("swift").standardizedFileURL
    searched.append(swiftURL.path)
    guard fileManager.isExecutableFile(atPath: swiftURL.path) else {
      return nil
    }
    return SwiftWebHostSwiftToolchain(
      swiftExecutableURL: swiftURL,
      binDirectory: binDirectory
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
      .trimmingCharacters(in: .whitespacesAndNewlines)
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
