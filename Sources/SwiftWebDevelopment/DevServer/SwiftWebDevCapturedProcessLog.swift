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
    try? handle.close()
  }

  func writeToStandardError() {
    guard let data = try? Data(contentsOf: fileURL), !data.isEmpty else {
      return
    }
    FileHandle.standardError.write(data)
  }

  func cleanup() {
    try? FileManager.default.removeItem(at: fileURL)
  }
}
