import SwiftCompilerPlugin
import SwiftSyntaxMacros

@main
struct SwiftWebMacrosPlugin: CompilerPlugin {
    let providingMacros: [Macro.Type] = [
        ActorMacro.self,
        PageMacro.self,
        ResolvableActorMacro.self,
        ServerActionMacro.self,
    ]
}
