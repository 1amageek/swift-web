import Foundation
import Testing

@Suite
struct StylePolicyStaticTests {
  @Test
  func swiftWebUIAndStoryboardDoNotUseRawSelectorsOrStyleAttributes() throws {
    let root = try projectRoot()
    let scannedRoots = [
      root.appending(path: "Sources/SwiftWebUI/Components"),
      root.appending(path: "Sources/SwiftWebDevelopment/Storyboard"),
    ]
    let commonForbiddenPatterns = [
      #"rule\(\s*#*""#,
      #"CSSSelector\(\s*#*""#,
      #"media\(\s*#*""#,
      #"supports\(\s*#*""#,
      #"container\(\s*#*""#,
      #"HTMLAttribute\("style""#,
      #"style=""#,
    ]
    let storyboardForbiddenPatterns = [
      #"\.custom\("#,
      #"\.style\s*\("#,
      #"\.style\s*\{"#,
      #"\.webStyle\s*\("#,
    ]

    for file in try swiftFiles(in: scannedRoots) {
      let source = try String(contentsOf: file, encoding: .utf8)
      let extraPatterns = file.path.contains("/Sources/SwiftWebDevelopment/Storyboard/")
        ? storyboardForbiddenPatterns
        : []
      for pattern in commonForbiddenPatterns + extraPatterns {
        #expect(
          source.range(of: pattern, options: .regularExpression) == nil,
          "\(file.path) contains forbidden style pattern \(pattern)"
        )
      }
    }
  }

  private func projectRoot() throws -> URL {
    var directory = URL(fileURLWithPath: #filePath)
    while directory.path != "/" {
      let candidate = directory.appending(path: "Package.swift")
      if FileManager.default.fileExists(atPath: candidate.path) {
        return directory
      }
      directory.deleteLastPathComponent()
    }
    throw StaticStylePolicyError.projectRootNotFound
  }

  private func swiftFiles(in roots: [URL]) throws -> [URL] {
    var files: [URL] = []
    for root in roots {
      guard let enumerator = FileManager.default.enumerator(
        at: root,
        includingPropertiesForKeys: [.isRegularFileKey],
        options: [.skipsHiddenFiles]
      ) else {
        continue
      }

      for case let file as URL in enumerator where file.pathExtension == "swift" {
        let values = try file.resourceValues(forKeys: [.isRegularFileKey])
        if values.isRegularFile == true {
          files.append(file)
        }
      }
    }
    return files
  }
}

private enum StaticStylePolicyError: Error {
  case projectRootNotFound
}
