struct WasmRuntimeEntrypointFormat {
  func entrypointSwift(
    context: GeneratedPackageRenderContext,
    target: WasmRuntimeTargetDeclaration
  ) -> String {
    switch context.wasmRuntimeProfile {
    case .standard:
      return standardWasmEntrypointSwift(appProductName: context.appProductName, target: target)
    case .embedded:
      return embeddedWasmEntrypointSwift(target: target)
    }
  }

  private func standardWasmEntrypointSwift(
    appProductName: String,
    target: WasmRuntimeTargetDeclaration
  ) -> String {
    let runtimeVariableName = "\(GeneratedPackageNameFormatter.lowerCamelCase(target.targetName))Runtime"
    let actorResolverVariableName =
      "\(GeneratedPackageNameFormatter.lowerCamelCase(target.targetName))ActorResolvers"
    let registrations = target.componentTypeNames.map { typeName in
      """
          ClientComponentRegistration(
              \(typeName).self,
              environmentRegistry: .swiftWebUI,
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

      private func makeSwiftWebWasmRoot<Root: HTML>(
          _ type: Root.Type,
          bootstrap request: ClientRuntimeBootstrapRequest,
          fallback: @autoclosure () -> Root
      ) throws -> Root {
          guard let bootstrapType = type as? any ClientRuntimeBootstrapInitializable.Type else {
              return fallback()
          }
          let root = try bootstrapType.init(bootstrap: request)
          guard let typedRoot = root as? Root else {
              throw ClientRuntimeBridgeError.componentMountNotFound(String(reflecting: type))
          }
          return typedRoot
      }

      nonisolated(unsafe) private let \(actorResolverVariableName) =
          SwiftWebGeneratedActorResolvers.\(WasmActorResolverRegistryFormat.functionName(for: target.targetName))()

      nonisolated(unsafe) private let \(runtimeVariableName) = ClientBundleRuntimeEntrypoint(
          registrations: [
      \(registrations)
          ]
      )

      @_cdecl("swiftweb_alloc")
      public func swiftweb_alloc(_ byteCount: UInt32) -> UInt32 {
          \(runtimeVariableName).allocate(byteCount: byteCount)
      }

      @_cdecl("swiftweb_dealloc")
      public func swiftweb_dealloc(_ pointer: UInt32, _ byteCount: UInt32) {
          \(runtimeVariableName).deallocate(pointer: pointer, byteCount: byteCount)
      }

      @_cdecl("swiftweb_bootstrap")
      public func swiftweb_bootstrap(_ pointer: UInt32, _ length: UInt32) -> UInt32 {
          \(runtimeVariableName).bootstrap(pointer: pointer, length: length)
      }

      @_cdecl("swiftweb_dispatch_event")
      public func swiftweb_dispatch_event(_ pointer: UInt32, _ length: UInt32) -> UInt32 {
          \(runtimeVariableName).dispatchEvent(pointer: pointer, length: length)
      }

      @_cdecl("swiftweb_snapshot_state")
      public func swiftweb_snapshot_state() -> UInt32 {
          \(runtimeVariableName).snapshotState()
      }

      @_cdecl("swiftweb_restore_state")
      public func swiftweb_restore_state(_ pointer: UInt32, _ length: UInt32) -> UInt32 {
          \(runtimeVariableName).restoreState(pointer: pointer, length: length)
      }

      @_cdecl("swiftweb_response_ptr")
      public func swiftweb_response_ptr() -> UInt32 {
          \(runtimeVariableName).responsePointer()
      }

      @_cdecl("swiftweb_response_len")
      public func swiftweb_response_len() -> UInt32 {
          \(runtimeVariableName).responseLength()
      }

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

  private func embeddedWasmEntrypointSwift(target: WasmRuntimeTargetDeclaration) -> String {
    let runtimeVariableName = "\(GeneratedPackageNameFormatter.lowerCamelCase(target.targetName))Runtime"
    return """
      import JavaScriptKit
      import SwiftHTMLClientRuntime

      nonisolated(unsafe) private let \(runtimeVariableName) = SwiftWebClientRuntime()

      @_cdecl("swiftweb_alloc")
      public func swiftweb_alloc(_ byteCount: UInt32) -> UInt32 {
          \(runtimeVariableName).allocate(byteCount: byteCount)
      }

      @_cdecl("swiftweb_dealloc")
      public func swiftweb_dealloc(_ pointer: UInt32, _ byteCount: UInt32) {
          \(runtimeVariableName).deallocate(pointer: pointer, byteCount: byteCount)
      }

      @_cdecl("swiftweb_bootstrap")
      public func swiftweb_bootstrap(_ pointer: UInt32, _ length: UInt32) -> UInt32 {
          \(runtimeVariableName).bootstrap(pointer: pointer, length: length)
      }

      @_cdecl("swiftweb_dispatch_event")
      public func swiftweb_dispatch_event(_ pointer: UInt32, _ length: UInt32) -> UInt32 {
          \(runtimeVariableName).dispatchEvent(pointer: pointer, length: length)
      }

      @_cdecl("swiftweb_snapshot_state")
      public func swiftweb_snapshot_state() -> UInt32 {
          \(runtimeVariableName).snapshotState()
      }

      @_cdecl("swiftweb_restore_state")
      public func swiftweb_restore_state(_ pointer: UInt32, _ length: UInt32) -> UInt32 {
          \(runtimeVariableName).restoreState(pointer: pointer, length: length)
      }

      @_cdecl("swiftweb_response_ptr")
      public func swiftweb_response_ptr() -> UInt32 {
          \(runtimeVariableName).responsePointer()
      }

      @_cdecl("swiftweb_response_len")
      public func swiftweb_response_len() -> UInt32 {
          \(runtimeVariableName).responseLength()
      }

      @_cdecl("swiftweb_response_free")
      public func swiftweb_response_free() {
          \(runtimeVariableName).freeResponse()
      }

      @main
      struct \(target.targetName)Main {
          static func main() {}
      }

      final class SwiftWebClientRuntime {
          private var bootstrapped = false

          func allocate(byteCount: UInt32) -> UInt32 {
              let pointer = UnsafeMutableRawPointer.allocate(
                  byteCount: Int(byteCount),
                  alignment: MemoryLayout<UInt8>.alignment
              )
              return UInt32(UInt(bitPattern: pointer))
          }

          func deallocate(pointer: UInt32, byteCount: UInt32) {
              guard let rawPointer = UnsafeMutableRawPointer(bitPattern: Int(pointer)) else {
                  return
              }
              rawPointer.deallocate()
          }

          func bootstrap(pointer: UInt32, length: UInt32) -> UInt32 {
              if !bootstrapped {
                  installRuntimeMarker()
                  bootstrapped = true
              }
              return 0
          }

          func dispatchEvent(pointer: UInt32, length: UInt32) -> UInt32 {
              0
          }

          func snapshotState() -> UInt32 {
              0
          }

          func restoreState(pointer: UInt32, length: UInt32) -> UInt32 {
              0
          }

          func responsePointer() -> UInt32 {
              0
          }

          func responseLength() -> UInt32 {
              0
          }

          func freeResponse() {
          }

          private func installRuntimeMarker() {
              #if os(WASI)
              let document = JSObject.global.document.object!
              let root = document.documentElement.object!
              _ = root.setAttribute!("data-swiftweb-runtime", "embedded")

              let tree = ClientHTMLDocument {}
              tree.mount(
                  into: SwiftWebClientDOMHost(document: document),
                  parent: root
              )
              #endif
          }
      }

      struct SwiftWebClientDOMHost: ClientDOMHost {
          let document: JSObject

          func createElement(_ tagName: String) -> JSObject {
              document.createElement!(tagName).object!
          }

          func createText(_ text: String) -> JSObject {
              document.createTextNode!(text).object!
          }

          func setAttribute(_ attribute: ClientHTMLAttribute, on node: JSObject) {
              _ = node.setAttribute!(attribute.name, attribute.value)
          }

          func appendChild(_ child: JSObject, to parent: JSObject) {
              _ = parent.appendChild!(child)
          }
      }
      """
  }
}
