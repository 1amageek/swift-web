import Foundation

struct PlatformAdapterManifest: Decodable {
    struct Templates: Decodable {
        let new: TemplateEntry?
        let named: [String: TemplateEntry]?
    }

    struct TemplateEntry: Decodable {
        let path: String
        let reference: Link
    }

    struct Link: Decodable, Equatable {
        let title: String
        let url: String
    }

    struct Capabilities: Decodable {
        let scaffold: Bool?
        let build: Bool?
        let deploy: Bool?
    }

    let schemaVersion: Int
    let id: String
    let name: String?
    let templates: Templates
    let capabilities: Capabilities?

    func selectedTemplatePath(
        for reference: PlatformAdapterReference,
        appTemplate: TemplateKind
    ) throws -> String {
        if let templatePath = reference.templatePath {
            if let namedPath = templates.named?[templatePath]?.path {
                return try validateTemplatePath(namedPath)
            }
            return try validateTemplatePath(templatePath)
        }

        if let templateName = appTemplate.platformTemplateName,
           let namedPath = templates.named?[templateName]?.path {
            return try validateTemplatePath(namedPath)
        }

        guard let newPath = templates.new?.path else {
            throw CLIError(message: "platform adapter \(id) does not define a default template", exitCode: 66)
        }
        return try validateTemplatePath(newPath)
    }

    private func validateTemplatePath(_ path: String) throws -> String {
        let parts = path.split(separator: "/", omittingEmptySubsequences: false).map(String.init)
        guard !parts.isEmpty else {
            throw CLIError(message: "platform adapter \(id) contains an empty template path", exitCode: 66)
        }
        guard !path.hasPrefix("/") else {
            throw CLIError(message: "platform adapter \(id) uses an absolute template path: \(path)", exitCode: 66)
        }
        guard parts.allSatisfy({ !$0.isEmpty && $0 != "." && $0 != ".." }) else {
            throw CLIError(message: "platform adapter \(id) uses an unsafe template path: \(path)", exitCode: 66)
        }
        return path
    }
}
