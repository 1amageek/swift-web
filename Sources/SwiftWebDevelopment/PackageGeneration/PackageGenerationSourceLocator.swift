import Foundation

enum PackageGenerationSourceLocator {
  static func packageDirectoryContainingThisFile(filePath: String = #filePath) -> URL {
    var directory = URL(fileURLWithPath: filePath).deletingLastPathComponent()
    while directory.lastPathComponent != "Sources" && directory.path != "/" {
      directory.deleteLastPathComponent()
    }
    if directory.lastPathComponent == "Sources" {
      return directory.deletingLastPathComponent()
    }
    return URL(fileURLWithPath: filePath).deletingLastPathComponent()
  }
}
