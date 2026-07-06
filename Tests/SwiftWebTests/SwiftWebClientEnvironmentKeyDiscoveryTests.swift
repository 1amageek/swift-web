import Foundation
import Testing

@testable import SwiftWebPackageGeneration

@Suite
struct SwiftWebClientEnvironmentKeyDiscoveryTests {
  @Test
  func discoversPublicTopLevelKeys() throws {
    let source = """
      import SwiftHTML
      import SwiftWebUI

      public struct SceneGreetingKey: ClientEnvironmentKey {
          public static let defaultValue = "default-greeting"
      }

      public enum SceneModeKey: SwiftHTML.ClientEnvironmentKey {
          public static var defaultValue: String { "mode" }
      }

      struct InternalKey: ClientEnvironmentKey {
          static let defaultValue = 0
      }

      public struct NotAKey: ClientComponent {
          public init() {}
      }
      """
    let names = try discover(source)
    #expect(names == ["SceneGreetingKey", "SceneModeKey"])
  }

  @Test
  func discoversKeyInRealBadgeFixture() throws {
    let source = #"""
import SwiftHTML
import SwiftWebUI

public struct SceneGreetingKey: ClientEnvironmentKey {
    public static let defaultValue = "default-greeting"
}

extension EnvironmentValues {
    public var sceneGreeting: String {
        get { self[SceneGreetingKey.self] }
        set { self[SceneGreetingKey.self] = newValue }
    }
}

public struct ClientEnvironmentBadge: ClientComponent, Sendable {
    @Environment(\.sceneGreeting) private var greeting
    @State private var revealed = false

    public init() {}

    public var body: some HTML {
        // Read during SSR as well, so the value enters the hydration snapshot.
        let greeting = self.greeting
        return GroupBox {
            VStack(spacing: .small) {
                Text("Scene Environment Badge").as(.h3)
                Text(revealed ? greeting : "waiting").as(.strong)
                    .accessibilityIdentifier("env-greeting")
                Button("Reveal environment") {
                    revealed = true
                }
            }
        }
        .accessibilityIdentifier("environment-badge")
        .frame(maxWidth: .infinity, alignment: .top)
    }
}
"""#
    let names = try discover(source)
    #expect(names == ["SceneGreetingKey"])
  }

  @Test
  func ignoresSourcesWithoutKeys() throws {
    let names = try discover("public struct Plain {}\n")
    #expect(names.isEmpty)
  }

  private func discover(_ source: String) throws -> [String] {
    let directory = FileManager.default.temporaryDirectory
      .appendingPathComponent("env-key-discovery-\(UUID().uuidString)", isDirectory: true)
    try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    let file = directory.appendingPathComponent("Fixture.swift")
    try source.write(to: file, atomically: true, encoding: .utf8)
    return try SwiftWebClientEnvironmentKeyDiscovery.discover(
      in: [(url: file, relativePath: "Fixture.swift")]
    )
  }
}
