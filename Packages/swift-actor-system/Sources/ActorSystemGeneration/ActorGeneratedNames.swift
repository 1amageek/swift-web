public enum ActorGeneratedNames {
    public static func schemaModuleTypeName(moduleName: String) -> String {
        "\(safeIdentifier(moduleName))ActorSchemaModule"
    }

    public static func bootstrapTypeName(moduleName: String) -> String {
        "\(safeIdentifier(moduleName))ActorSystemBootstrap"
    }

    private static func safeIdentifier(_ value: String) -> String {
        let mapped = value.map { character in
            character.isLetter || character.isNumber || character == "_" ? character : "_"
        }
        let result = String(mapped)
        return result.first?.isNumber == true ? "_\(result)" : result
    }
}
