import SwiftSyntaxMacros
import SwiftSyntaxMacrosTestSupport
import SwiftWebMacros
import XCTest

final class ResolvableActorMacroTests: XCTestCase {
    private let macros: [String: any Macro.Type] = [
        "ResolvableActor": ResolvableActorMacro.self,
    ]

    func testResolvableActorExportsContractMetadata() {
        assertMacroExpansion(
            """
            @ResolvableActor(CounterServiceProtocol.self)
            distributed actor CounterService: CounterServiceProtocol {
            }
            """,
            expandedSource: """
            distributed actor CounterService: CounterServiceProtocol {
            }

            extension CounterService: SwiftWebActorExporting {
                typealias SwiftWebActorContract = $CounterServiceProtocol

                nonisolated static var swiftWebActorContractKey: SwiftWebActorContractKey {
                    SwiftWebActorContractKey(String(reflecting: (any CounterServiceProtocol).self))
                }

                nonisolated static func _swiftWebActorContractTypeCheck(_ actor: CounterService) -> any CounterServiceProtocol {
                    actor
                }
            }
            """,
            macros: macros
        )
    }

    func testResolvableActorAcceptsExplicitExistentialMetatype() {
        assertMacroExpansion(
            """
            @ResolvableActor((any Services.CounterServiceProtocol).self)
            distributed actor CounterService: Services.CounterServiceProtocol {
            }
            """,
            expandedSource: """
            distributed actor CounterService: Services.CounterServiceProtocol {
            }

            extension CounterService: SwiftWebActorExporting {
                typealias SwiftWebActorContract = Services.$CounterServiceProtocol

                nonisolated static var swiftWebActorContractKey: SwiftWebActorContractKey {
                    SwiftWebActorContractKey(String(reflecting: (any Services.CounterServiceProtocol).self))
                }

                nonisolated static func _swiftWebActorContractTypeCheck(_ actor: CounterService) -> any Services.CounterServiceProtocol {
                    actor
                }
            }
            """,
            macros: macros
        )
    }
}
