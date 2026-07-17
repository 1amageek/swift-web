import Testing

@testable import SwiftWebPackageGeneration

@Suite
struct SwiftWebClientActorPropertyExpanderTests {
  @Test
  func expandsActorPropertyIntoResolvedAccessor() throws {
    let source = """
      public struct ClientSample: ClientComponent {
          @RemoteActor private var service: any SampleServiceProtocol

          public init() {}
      }
      """
    let expanded = try SwiftWebClientActorPropertyExpander.expandActorProperties(
      inSource: source,
      filePath: "ClientSample.swift"
    )
    let expected = """
      public struct ClientSample: ClientComponent {
          private var service: any SampleServiceProtocol {
              get {
                  SwiftWebActorBinding.resolve(
                      (any SampleServiceProtocol).self,
                      contract: SwiftWebActorContractKey(String(reflecting: (any SampleServiceProtocol).self))
                  )
              }
          }

          public init() {}
      }
      """
    #expect(expanded == expected)
  }

  @Test
  func expandsQualifiedActorAttributeAndType() throws {
    let source = """
      struct Client {
          @SwiftWebActors.RemoteActor var service: any Services.SampleServiceProtocol
      }
      """
    let expanded = try SwiftWebClientActorPropertyExpander.expandActorProperties(
      inSource: source,
      filePath: "Client.swift"
    )
    #expect(!expanded.contains("@SwiftWebActors.RemoteActor"))
    #expect(expanded.contains("var service: any Services.SampleServiceProtocol {"))
    #expect(
      expanded.contains(
        "SwiftWebActorContractKey(String(reflecting: (any Services.SampleServiceProtocol).self))"
      ))
  }

  @Test
  func keepsSourceWithoutActorPropertiesUnchanged() throws {
    let source = """
      public struct ClientBadge: ClientComponent {
          @State private var count = 0

          public init() {}
      }
      """
    let expanded = try SwiftWebClientActorPropertyExpander.expandActorProperties(
      inSource: source,
      filePath: "ClientBadge.swift"
    )
    #expect(expanded == source)
  }

  @Test
  func rejectsActorPropertyWithoutTypeAnnotation() {
    let source = """
      struct Client {
          @RemoteActor var service = SampleService()
      }
      """
    #expect(
      throws: SwiftWebClientActorPropertyExpansionError.unsupportedActorProperty(
        filePath: "Client.swift",
        reason: "@RemoteActor property cannot have an initial value"
      )
    ) {
      try SwiftWebClientActorPropertyExpander.expandActorProperties(
        inSource: source,
        filePath: "Client.swift"
      )
    }
  }

  @Test
  func rejectsActorLetProperty() {
    let source = """
      struct Client {
          @RemoteActor let service: any SampleServiceProtocol
      }
      """
    #expect(
      throws: SwiftWebClientActorPropertyExpansionError.unsupportedActorProperty(
        filePath: "Client.swift",
        reason: "@RemoteActor requires a 'var' property"
      )
    ) {
      try SwiftWebClientActorPropertyExpander.expandActorProperties(
        inSource: source,
        filePath: "Client.swift"
      )
    }
  }

  @Test
  func rejectsStaticActorProperty() {
    let source = """
      struct Client {
          @RemoteActor static var service: any SampleServiceProtocol
      }
      """
    #expect(
      throws: SwiftWebClientActorPropertyExpansionError.unsupportedActorProperty(
        filePath: "Client.swift",
        reason: "@RemoteActor cannot be applied to a static property"
      )
    ) {
      try SwiftWebClientActorPropertyExpander.expandActorProperties(
        inSource: source,
        filePath: "Client.swift"
      )
    }
  }
}
