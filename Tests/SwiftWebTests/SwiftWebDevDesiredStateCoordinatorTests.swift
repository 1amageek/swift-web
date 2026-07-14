import Foundation
import Synchronization
import Testing

@testable import SwiftWebDevServer
@testable import SwiftWebPackageGeneration

@Suite
struct SwiftWebDevDesiredStateCoordinatorTests {
  @Test
  func unassociatedInitialPackageIsPreparedForFirstFingerprint() async throws {
    let preparations = Mutex(0)
    let package = generatedPackage(componentTypeNames: ["InitialComponent"])
    let coordinator = SwiftWebDevDesiredStateCoordinator(
      currentPackage: package,
      preparePackage: {
        preparations.withLock { $0 += 1 }
        return package
      },
      prepareClientRuntimes: { _, _ in }
    )

    _ = try await coordinator.prepare(for: fingerprint("a"))
    _ = try await coordinator.prepare(for: fingerprint("a"))

    #expect(preparations.withLock { $0 } == 1)
  }

  @Test
  func preparesGeneratedPackageAndClientRuntimesOncePerFingerprint() async throws {
    let packagePreparations = Mutex(0)
    let preparedComponents = Mutex<[[String]]>([])
    let initial = generatedPackage(componentTypeNames: ["OldComponent"])
    let refreshed = generatedPackage(componentTypeNames: ["NewComponent"])
    let coordinator = SwiftWebDevDesiredStateCoordinator(
      currentPackage: initial,
      readyFingerprint: fingerprint("a"),
      preparePackage: {
        packagePreparations.withLock { $0 += 1 }
        return refreshed
      },
      prepareClientRuntimes: { package, _ in
        preparedComponents.withLock {
          $0.append(package.wasmRuntimes.flatMap(\.componentTypeNames))
        }
      }
    )

    let first = try await coordinator.prepare(
      for: fingerprint("b"),
      changedPaths: ["Sources/App/NewComponent.swift"]
    )
    let second = try await coordinator.prepare(for: fingerprint("b"))

    #expect(first.wasmRuntimes.flatMap(\.componentTypeNames) == ["NewComponent"])
    #expect(second.wasmRuntimes == first.wasmRuntimes)
    #expect(packagePreparations.withLock { $0 } == 1)
    #expect(preparedComponents.withLock { $0 } == [["NewComponent"]])
  }

  private func generatedPackage(componentTypeNames: [String]) -> SwiftWebGeneratedPackage {
    let root = URL(fileURLWithPath: "/tmp/swiftweb-desired-state", isDirectory: true)
    return SwiftWebGeneratedPackage(
      appPackageDirectory: root,
      packageDirectory: root.appendingPathComponent("server", isDirectory: true),
      swiftWebPackageDirectory: root.appendingPathComponent("swift-web", isDirectory: true),
      appProductName: "App",
      serverProductName: "app-server",
      devProductName: "App",
      wasmProductNames: ["app-wasm-runtime"],
      wasmRuntimes: [
        SwiftWebGeneratedWasmRuntime(
          targetName: "AppWasmRuntime",
          productName: "app-wasm-runtime",
          componentTypeNames: componentTypeNames,
          assetPath: "/assets/app.wasm"
        )
      ]
    )
  }

  private func fingerprint(_ character: Character) -> SwiftWebDevSourceFingerprint {
    SwiftWebDevSourceFingerprint(
      digest: String(repeating: String(character), count: 64),
      fileCount: 1
    )
  }
}
