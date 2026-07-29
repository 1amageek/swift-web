import SwiftWebDevelopmentHooks
import SwiftWebWasmBuild
import Foundation

public enum SwiftWebPackageReference {
  public static let localPathEnvironmentKey = "SWIFT_WEB_PACKAGE_PATH"
  public static let packageName = "swift-web"
  public static let repositoryURL = "https://github.com/1amageek/swift-web.git"
  public static let branch = "main"
  public static let minimumVersion = "0.8.0"

  public static var packageDependencyDeclaration: String {
    if let localPath = ProcessInfo.processInfo.environment[localPathEnvironmentKey],
       !localPath.isEmpty {
      let escapedPath = localPath
        .replacingOccurrences(of: "\\", with: "\\\\")
        .replacingOccurrences(of: "\"", with: "\\\"")
      return #".package(path: "\#(escapedPath)")"#
    }
    return #".package(url: "\#(repositoryURL)", from: "\#(minimumVersion)")"#
  }
}
