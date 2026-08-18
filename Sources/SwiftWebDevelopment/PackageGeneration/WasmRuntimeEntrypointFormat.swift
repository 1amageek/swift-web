struct WasmRuntimeEntrypointFormat {
  func entrypointSwift(
    context: GeneratedPackageRenderContext,
    target: WasmRuntimeTargetDeclaration
  ) -> String {
    standardWasmEntrypointSwift(
      appProductName: context.appProductName,
      environmentKeyTypeNames: context.clientEnvironmentKeyTypeNames,
      target: target
    )
  }

  private func standardWasmEntrypointSwift(
    appProductName: String,
    environmentKeyTypeNames: [String],
    target: WasmRuntimeTargetDeclaration
  ) -> String {
    let runtimeVariableName = "\(GeneratedPackageNameFormatter.lowerCamelCase(target.targetName))Runtime"
    let actorResolverVariableName =
      "\(GeneratedPackageNameFormatter.lowerCamelCase(target.targetName))ActorResolvers"
    let environmentRegistryVariableName =
      "\(GeneratedPackageNameFormatter.lowerCamelCase(target.targetName))EnvironmentRegistry"
    // App-defined ClientEnvironmentKey conformances extend the framework
    // registry; a key missing from the registry aborts hydration with
    // missingDecoder.
    let registeringCalls = environmentKeyTypeNames
      .map { "\n    .registering(\($0).self)" }
      .joined()
    let environmentRegistryDeclaration =
      "private let \(environmentRegistryVariableName) = "
      + "ClientEnvironmentRegistry.swiftWebUI\(registeringCalls)"
    let bootstrapHelper = """
      private func makeSwiftWebWasmRoot<Root: Component>(
          _ type: Root.Type,
          bootstrap request: ClientRuntimeBootstrapRequest,
          fallback: @autoclosure () -> Root
      ) throws -> Root {
          fallback()
      }

      private func makeSwiftWebWasmRoot<Root: ClientRuntimeBootstrapInitializable>(
          _ type: Root.Type,
          bootstrap request: ClientRuntimeBootstrapRequest,
          fallback: @autoclosure () -> Root
      ) throws -> Root {
          try Root(bootstrap: request)
      }
      """
    let registrations = target.componentTypeNames.map { typeName in
      return """
          ClientComponentRegistration(
              \(typeName).self,
              typeName: "\(typeName)",
              environmentRegistry: \(environmentRegistryVariableName),
              actorResolverRegistry: \(actorResolverVariableName)
          ) { request in
              try makeSwiftWebWasmRoot(
                  \(typeName).self,
                  bootstrap: request,
                  fallback: \(typeName)()
              )
          }
      """
    }
    .joined(separator: ",\n")
    return """
      import \(appProductName)
      import SwiftHTML
      import SwiftWebActors
      import SwiftWebUI
      import SwiftWebUIRuntime

      \(bootstrapHelper)

      private let \(actorResolverVariableName) =
          SwiftWebGeneratedActorResolvers.\(WasmActorResolverRegistryFormat.functionName(for: target.targetName))()

      \(environmentRegistryDeclaration)

      @MainActor private let \(runtimeVariableName) = ClientBundleRuntimeEntrypoint(
          registrations: [
      \(registrations)
          ]
      )

      @MainActor
      @_cdecl("swiftweb_alloc")
      public func swiftweb_alloc(_ byteCount: UInt32) -> UInt32 {
          \(runtimeVariableName).allocate(byteCount: byteCount)
      }

      @MainActor
      @_cdecl("swiftweb_dealloc")
      public func swiftweb_dealloc(_ pointer: UInt32, _ byteCount: UInt32) {
          \(runtimeVariableName).deallocate(pointer: pointer, byteCount: byteCount)
      }

      @MainActor
      @_cdecl("swiftweb_bootstrap")
      public func swiftweb_bootstrap(_ pointer: UInt32, _ length: UInt32) -> UInt32 {
          \(runtimeVariableName).bootstrap(pointer: pointer, length: length)
      }

      @MainActor
      @_cdecl("swiftweb_start")
      public func swiftweb_start() -> UInt32 {
          \(runtimeVariableName).start()
      }

      @MainActor
      @_cdecl("swiftweb_start_status")
      public func swiftweb_start_status() -> UInt32 {
          \(runtimeVariableName).startStatus()
      }

      @MainActor
      @_cdecl("swiftweb_shutdown")
      public func swiftweb_shutdown() -> UInt32 {
          \(runtimeVariableName).shutdown()
      }

      @MainActor
      @_cdecl("swiftweb_shutdown_status")
      public func swiftweb_shutdown_status() -> UInt32 {
          \(runtimeVariableName).shutdownStatus()
      }

      @MainActor
      @_cdecl("swiftweb_dispatch_event")
      public func swiftweb_dispatch_event(_ pointer: UInt32, _ length: UInt32) -> UInt32 {
          \(runtimeVariableName).dispatchEvent(pointer: pointer, length: length)
      }

      @MainActor
      @_cdecl("swiftweb_snapshot_state")
      public func swiftweb_snapshot_state() -> UInt32 {
          \(runtimeVariableName).snapshotState()
      }

      @MainActor
      @_cdecl("swiftweb_restore_state")
      public func swiftweb_restore_state(_ pointer: UInt32, _ length: UInt32) -> UInt32 {
          \(runtimeVariableName).restoreState(pointer: pointer, length: length)
      }

      @MainActor
      @_cdecl("swiftweb_response_len")
      public func swiftweb_response_len() -> UInt32 {
          \(runtimeVariableName).responseLength()
      }

      @MainActor
      @_cdecl("swiftweb_response_copy")
      public func swiftweb_response_copy(_ pointer: UInt32, _ capacity: UInt32) -> UInt32 {
          \(runtimeVariableName).copyResponse(pointer: pointer, capacity: capacity)
      }

      @MainActor
      @_cdecl("swiftweb_response_free")
      public func swiftweb_response_free() {
          \(runtimeVariableName).freeResponse()
      }

      @main
      struct \(target.targetName)Main {
          static func main() {}
      }
      """
  }

}
