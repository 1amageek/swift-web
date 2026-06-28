import SwiftWebDevelopmentHooks
import SwiftWebWasmBuild
public enum SwiftWebPackageReference {
  public static let packageName = "swift-web"
  public static let repositoryURL = "https://github.com/1amageek/swift-web.git"
  public static let branch = "main"

  public static var packageDependencyDeclaration: String {
    #".package(url: "\#(repositoryURL)", branch: "\#(branch)")"#
  }
}
