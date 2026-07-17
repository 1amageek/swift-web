import SwiftSyntaxMacros
import SwiftSyntaxMacrosTestSupport
import SwiftWebMacros
import XCTest

final class RemoteActorMacroTests: XCTestCase {
    private let macros: [String: any Macro.Type] = [
        "RemoteActor": RemoteActorMacro.self,
    ]

    func testActorExpandsResolvedAccessor() {
        assertMacroExpansion(
            """
            struct CounterClient {
                @RemoteActor private var counter: any CounterServiceProtocol
            }
            """,
            expandedSource: """
            struct CounterClient {
                private var counter: any CounterServiceProtocol {
                    get {
                        SwiftWebActorBinding.resolve(
                            (any CounterServiceProtocol).self,
                            contract: SwiftWebActorContractKey(String(reflecting: (any CounterServiceProtocol).self))
                        )
                    }
                }
            }
            """,
            macros: macros
        )
    }

    func testActorExpandsQualifiedExistentialType() {
        assertMacroExpansion(
            """
            struct CounterClient {
                @RemoteActor var counter: any Services.CounterServiceProtocol
            }
            """,
            expandedSource: """
            struct CounterClient {
                var counter: any Services.CounterServiceProtocol {
                    get {
                        SwiftWebActorBinding.resolve(
                            (any Services.CounterServiceProtocol).self,
                            contract: SwiftWebActorContractKey(String(reflecting: (any Services.CounterServiceProtocol).self))
                        )
                    }
                }
            }
            """,
            macros: macros
        )
    }

    func testActorRequiresVarProperty() {
        assertMacroExpansion(
            """
            struct CounterClient {
                @RemoteActor let counter: any CounterServiceProtocol
            }
            """,
            expandedSource: """
            struct CounterClient {
                let counter: any CounterServiceProtocol
            }
            """,
            diagnostics: [
                DiagnosticSpec(message: "@RemoteActor requires a 'var' property", line: 2, column: 18)
            ],
            macros: macros
        )
    }

    func testActorRequiresTypeAnnotation() {
        assertMacroExpansion(
            """
            struct CounterClient {
                @RemoteActor var counter
            }
            """,
            expandedSource: """
            struct CounterClient {
                var counter
            }
            """,
            diagnostics: [
                DiagnosticSpec(message: "@RemoteActor requires an explicit type annotation", line: 2, column: 22)
            ],
            macros: macros
        )
    }

    func testActorRejectsInitialValue() {
        assertMacroExpansion(
            """
            struct CounterClient {
                @RemoteActor var counter: any CounterServiceProtocol = fallbackCounter
            }
            """,
            expandedSource: """
            struct CounterClient {
                var counter: any CounterServiceProtocol = fallbackCounter
            }
            """,
            diagnostics: [
                DiagnosticSpec(message: "@RemoteActor property cannot have an initial value", line: 2, column: 22)
            ],
            macros: macros
        )
    }

    func testActorRejectsStaticProperty() {
        assertMacroExpansion(
            """
            struct CounterClient {
                @RemoteActor static var counter: any CounterServiceProtocol
            }
            """,
            expandedSource: """
            struct CounterClient {
                static var counter: any CounterServiceProtocol
            }
            """,
            diagnostics: [
                DiagnosticSpec(message: "@RemoteActor cannot be applied to a static property", line: 2, column: 5)
            ],
            macros: macros
        )
    }
}
