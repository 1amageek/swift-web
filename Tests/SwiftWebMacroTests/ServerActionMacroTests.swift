import SwiftSyntaxMacros
import SwiftSyntaxMacrosTestSupport
import SwiftWebMacros
import XCTest

final class ServerActionMacroTests: XCTestCase {
    private let macros: [String: any Macro.Type] = [
        "ServerAction": ServerActionMacro.self,
    ]

    func testDistributedFunctionProducesBuildDiagnostic() {
        assertMacroExpansion(
            """
            actor CounterHandler {
                @ServerAction("submit")
                distributed func submit(_ input: Input, context: SwiftWeb.ActionInvocationContext) async throws -> Output {
                    output
                }
            }
            """,
            expandedSource: """
            actor CounterHandler {
                distributed func submit(_ input: Input, context: SwiftWeb.ActionInvocationContext) async throws -> Output {
                    output
                }
            }
            """,
            diagnostics: [
                DiagnosticSpec(
                    message: "@ServerAction function must not be distributed; use @Resolvable for distributed actor RPC",
                    line: 2,
                    column: 5
                ),
            ],
            macros: macros
        )
    }

    func testStaticFunctionProducesBuildDiagnostic() {
        assertMacroExpansion(
            """
            final class CounterHandler {
                @ServerAction("submit")
                static func submit(_ input: Input, context: SwiftWeb.ActionInvocationContext) throws -> Output {
                    output
                }
            }
            """,
            expandedSource: """
            final class CounterHandler {
                static func submit(_ input: Input, context: SwiftWeb.ActionInvocationContext) throws -> Output {
                    output
                }
            }
            """,
            diagnostics: [
                DiagnosticSpec(
                    message: "@ServerAction function must be an instance function",
                    line: 2,
                    column: 5
                ),
            ],
            macros: macros
        )
    }

    func testClassFunctionProducesBuildDiagnostic() {
        assertMacroExpansion(
            """
            class CounterHandler {
                @ServerAction("submit")
                class func submit(_ input: Input, context: SwiftWeb.ActionInvocationContext) throws -> Output {
                    output
                }
            }
            """,
            expandedSource: """
            class CounterHandler {
                class func submit(_ input: Input, context: SwiftWeb.ActionInvocationContext) throws -> Output {
                    output
                }
            }
            """,
            diagnostics: [
                DiagnosticSpec(
                    message: "@ServerAction function must be an instance function",
                    line: 2,
                    column: 5
                ),
            ],
            macros: macros
        )
    }

    func testDynamicPathProducesBuildDiagnostic() {
        assertMacroExpansion(
            """
            final class CounterHandler {
                let path = "dynamic"

                @ServerAction(path)
                func submit(_ input: Input, context: SwiftWeb.ActionInvocationContext) throws -> Output {
                    output
                }
            }
            """,
            expandedSource: """
            final class CounterHandler {
                let path = "dynamic"
                func submit(_ input: Input, context: SwiftWeb.ActionInvocationContext) throws -> Output {
                    output
                }
            }
            """,
            diagnostics: [
                DiagnosticSpec(
                    message: "@ServerAction path must be a static string literal",
                    line: 4,
                    column: 19
                ),
            ],
            macros: macros
        )
    }

    func testHTTPRouteExpansionInsideStruct() {
        assertMacroExpansion(
            """
            struct CounterPage {
                @ServerAction(.put, "submit")
                func submit(_ input: Input) async throws -> Output {
                    output
                }
            }
            """,
            expandedSource: """
            struct CounterPage {
                func submit(_ input: Input) async throws -> Output {
                    output
                }

                func _swiftweb_submitServerActionBridge(_ input: Input, context: SwiftWeb.ActionInvocationContext) async throws -> Output {
                    try await submit(input)
                }

                let _swiftweb_submitServerActionDescriptor: SwiftWeb.ServerActionDescriptor = SwiftWeb.ServerActionDescriptor(
                    handlerType: CounterPage.self,
                    method: SwiftWeb.ServerActionMethod.put,
                    path: "submit",
                    inputType: Input.self,
                    outputType: Output.self
                ) { handler, input, context in
                    try await handler._swiftweb_submitServerActionBridge(input, context: context)
                }

                var submitAction: SwiftWeb.ActionReference<Input, Output> {
                    SwiftWeb.ActionReference(
                        path: SwiftWeb.ServerActionPath.renderedPath("submit"),
                        httpMethod: SwiftWeb.ServerActionMethod.put,
                        inputType: String(reflecting: Input.self),
                        outputType: String(reflecting: Output.self)
                    )
                }
            }
            """,
            macros: macros
        )
    }
}
