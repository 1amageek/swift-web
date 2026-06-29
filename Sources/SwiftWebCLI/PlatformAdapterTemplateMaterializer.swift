import Foundation

struct PlatformAdapterTemplateMaterializer {
    private let repositoryCloner: PlatformAdapterRepositoryCloning
    private let fileManager: FileManager

    init(
        repositoryCloner: PlatformAdapterRepositoryCloning = GitPlatformAdapterRepositoryCloner(),
        fileManager: FileManager = .default
    ) {
        self.repositoryCloner = repositoryCloner
        self.fileManager = fileManager
    }

    func materialize(project: TemplateProject) throws {
        guard let platform = project.platform else {
            return
        }

        let temporaryDirectory = fileManager.temporaryDirectory
            .appendingPathComponent("swiftweb-platform-\(UUID().uuidString)", isDirectory: true)
        let checkoutDirectory = temporaryDirectory.appendingPathComponent("repository", isDirectory: true)

        do {
            try fileManager.createDirectory(at: temporaryDirectory, withIntermediateDirectories: true)
            try repositoryCloner.clone(platform, to: checkoutDirectory)
            try materialize(
                platform: platform,
                project: project,
                checkoutDirectory: checkoutDirectory
            )
            try fileManager.removeItem(at: temporaryDirectory)
        } catch {
            removeTemporaryDirectoryIfPresent(temporaryDirectory)
            throw error
        }
    }

    private func materialize(
        platform: PlatformAdapterReference,
        project: TemplateProject,
        checkoutDirectory: URL
    ) throws {
        let manifestURL = checkoutDirectory.appendingPathComponent("sweb.json")
        guard fileManager.fileExists(atPath: manifestURL.path) else {
            throw CLIError(
                message: "platform adapter \(platform.repositorySlug) is missing sweb.json",
                exitCode: 66
            )
        }

        let manifestData = try Data(contentsOf: manifestURL)
        let manifest = try JSONDecoder().decode(PlatformAdapterManifest.self, from: manifestData)
        guard manifest.schemaVersion == 1 else {
            throw CLIError(
                message: "unsupported platform adapter schema version \(manifest.schemaVersion) in \(platform.repositorySlug)",
                exitCode: 66
            )
        }

        let templatePath = try manifest.selectedTemplatePath(
            for: platform,
            appTemplate: project.template
        )
        let templateDirectory = checkoutDirectory.appendingPathComponent(templatePath, isDirectory: true)
        try ensureTemplateDirectory(templateDirectory, platform: platform, templatePath: templatePath)
        try copyTemplateDirectory(templateDirectory, to: project.projectDirectory, project: project)
    }

    private func ensureTemplateDirectory(
        _ templateDirectory: URL,
        platform: PlatformAdapterReference,
        templatePath: String
    ) throws {
        var isDirectory: ObjCBool = false
        guard fileManager.fileExists(atPath: templateDirectory.path, isDirectory: &isDirectory),
              isDirectory.boolValue else {
            throw CLIError(
                message: "platform adapter \(platform.repositorySlug) template does not exist: \(templatePath)",
                exitCode: 66
            )
        }
    }

    private func copyTemplateDirectory(
        _ sourceDirectory: URL,
        to destinationRoot: URL,
        project: TemplateProject
    ) throws {
        guard let enumerator = fileManager.enumerator(
            at: sourceDirectory,
            includingPropertiesForKeys: [.isDirectoryKey, .isRegularFileKey, .isSymbolicLinkKey],
            options: []
        ) else {
            throw CLIError(message: "failed to enumerate platform template: \(sourceDirectory.path)", exitCode: 66)
        }

        for case let sourceURL as URL in enumerator {
            let relativePath = try relativePath(for: sourceURL, under: sourceDirectory)
            if relativePath.split(separator: "/").contains(".git") {
                enumerator.skipDescendants()
                continue
            }

            let destinationURL = destinationRoot.appendingPathComponent(relativePath)
            let values = try sourceURL.resourceValues(
                forKeys: [.isDirectoryKey, .isRegularFileKey, .isSymbolicLinkKey]
            )

            if values.isSymbolicLink == true {
                throw CLIError(
                    message: "platform adapter templates cannot contain symlinks: \(relativePath)",
                    exitCode: 66
                )
            }

            if values.isDirectory == true {
                try fileManager.createDirectory(at: destinationURL, withIntermediateDirectories: true)
                continue
            }

            guard values.isRegularFile == true else {
                continue
            }

            try materializeFile(sourceURL, to: destinationURL, relativePath: relativePath, project: project)
        }
    }

    private func materializeFile(
        _ sourceURL: URL,
        to destinationURL: URL,
        relativePath: String,
        project: TemplateProject
    ) throws {
        if fileManager.fileExists(atPath: destinationURL.path) {
            throw CLIError(
                message: "platform adapter would overwrite an existing file: \(relativePath)",
                exitCode: 73
            )
        }

        try fileManager.createDirectory(
            at: destinationURL.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )

        let data = try Data(contentsOf: sourceURL)
        if let text = String(data: data, encoding: .utf8) {
            let rendered = render(text, project: project)
            try rendered.write(to: destinationURL, atomically: true, encoding: .utf8)
        } else {
            try data.write(to: destinationURL, options: .atomic)
        }

        let attributes = try fileManager.attributesOfItem(atPath: sourceURL.path)
        if let permissions = attributes[.posixPermissions] {
            try fileManager.setAttributes([.posixPermissions: permissions], ofItemAtPath: destinationURL.path)
        }
    }

    private func render(_ text: String, project: TemplateProject) -> String {
        text
            .replacingOccurrences(of: "{{app.name}}", with: project.appName)
            .replacingOccurrences(of: "{{app.moduleName}}", with: project.moduleName)
            .replacingOccurrences(of: "{{app.kebabName}}", with: project.kebabName)
    }

    private func relativePath(for url: URL, under root: URL) throws -> String {
        let rootPath = root.standardizedFileURL.path
        let urlPath = url.standardizedFileURL.path
        let prefix = rootPath.hasSuffix("/") ? rootPath : rootPath + "/"
        guard urlPath.hasPrefix(prefix) else {
            throw CLIError(message: "template path escaped its source directory: \(urlPath)", exitCode: 66)
        }
        let relativePath = String(urlPath.dropFirst(prefix.count))
        guard !relativePath.isEmpty else {
            throw CLIError(message: "template path resolved to an empty relative path", exitCode: 66)
        }
        guard !relativePath.split(separator: "/").contains("..") else {
            throw CLIError(message: "template path contains an unsafe segment: \(relativePath)", exitCode: 66)
        }
        return relativePath
    }

    private func removeTemporaryDirectoryIfPresent(_ directory: URL) {
        guard fileManager.fileExists(atPath: directory.path) else {
            return
        }

        do {
            try fileManager.removeItem(at: directory)
        } catch {
            FileHandle.standardError.write(
                Data("warning: failed to remove temporary platform adapter directory: \(directory.path)\n".utf8)
            )
        }
    }
}
