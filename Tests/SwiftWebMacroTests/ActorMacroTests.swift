import SwiftSyntaxMacros
import SwiftSyntaxMacrosTestSupport
import SwiftWebMacros
import XCTest

final class ActorMacroTests: XCTestCase {
    private let macros: [String: any Macro.Type] = [
        "Actor": ActorMacro.self,
    ]

    func testActorExpandsResolvedAccessor() {
        assertMacroExpansion(
            """
            struct CounterClient {
                @Actor private var counter: any CounterServiceProtocol
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
                @Actor var counter: any Services.CounterServiceProtocol
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
                @Actor let counter: any CounterServiceProtocol
            }
            """,
            expandedSource: """
            struct CounterClient {
                let counter: any CounterServiceProtocol
            }
            """,
            diagnostics: [
                DiagnosticSpec(message: "@Actor requires a 'var' property", line: 2, column: 12)
            ],
            macros: macros
        )
    }

    func testActorRequiresTypeAnnotation() {
        assertMacroExpansion(
            """
            struct CounterClient {
                @Actor var counter
            }
            """,
            expandedSource: """
            struct CounterClient {
                var counter
            }
            """,
            diagnostics: [
                DiagnosticSpec(message: "@Actor requires an explicit type annotation", line: 2, column: 16)
            ],
            macros: macros
        )
    }

    func testActorRejectsInitialValue() {
        assertMacroExpansion(
            """
            struct CounterClient {
                @Actor var counter: any CounterServiceProtocol = fallbackCounter
            }
            """,
            expandedSource: """
            struct CounterClient {
                var counter: any CounterServiceProtocol = fallbackCounter
            }
            """,
            diagnostics: [
                DiagnosticSpec(message: "@Actor property cannot have an initial value", line: 2, column: 16)
            ],
            macros: macros
        )
    }

    func testActorRejectsStaticProperty() {
        assertMacroExpansion(
            """
            struct CounterClient {
                @Actor static var counter: any CounterServiceProtocol
            }
            """,
            expandedSource: """
            struct CounterClient {
                static var counter: any CounterServiceProtocol
            }
            """,
            diagnostics: [
                DiagnosticSpec(message: "@Actor cannot be applied to a static property", line: 2, column: 5)
            ],
            macros: macros
        )
    }
}
