import SwiftWebDevelopmentHooks
import SwiftWebPackageGeneration
import SwiftWebWasmBuild
import Foundation

struct SwiftWebDevCapturedProcessLog {
  let fileURL: URL
  let handle: FileHandle

  static func create(prefix: String) throws -> SwiftWebDevCapturedProcessLog {
    let fileURL = FileManager.default.temporaryDirectory
      .appendingPathComponent("\(prefix)-\(UUID().uuidString).log")
    FileManager.default.createFile(atPath: fileURL.path, contents: nil)
    let handle = try FileHandle(forWritingTo: fileURL)
    return SwiftWebDevCapturedProcessLog(fileURL: fileURL, handle: handle)
  }

  func close() {
    do {
      try handle.close()
    } catch {
      report("Failed to close captured process log", error: error)
    }
  }

  func writeToStandardError() {
    let data: Data
    do {
      data = try Data(contentsOf: fileURL)
    } catch {
      report("Failed to read captured process log", error: error)
      return
    }
    guard !data.isEmpty else {
      return
    }
    FileHandle.standardError.write(data)
  }

  func cleanup() {
    guard FileManager.default.fileExists(atPath: fileURL.path) else {
      return
    }
    do {
      try FileManager.default.removeItem(at: fileURL)
    } catch {
      report("Failed to remove captured process log", error: error)
    }
  }

  private func report(_ message: String, error: any Error) {
    FileHandle.standardError.write(
      Data("\(message) at \(fileURL.path): \(String(describing: error))\n".utf8)
    )
  }
}
