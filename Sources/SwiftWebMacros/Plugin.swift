import SwiftCompilerPlugin
import SwiftSyntaxMacros

@main
struct SwiftWebMacrosPlugin: CompilerPlugin {
    let providingMacros: [Macro.Type] = [
        PageMacro.self,
        ResolvableActorMacro.self,
        ServerActionMacro.self,
    ]
}
