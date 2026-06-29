import Foundation
import Testing
@testable import SwiftWebCLI

@Suite
struct NewCommandTemplateTests {
    @Test
    func parseAcceptsAIFlag() throws {
        let command = try NewCommand.parse(
            ArgumentParser(arguments: ["Chat", "--ai", "--output", "/tmp"])
        )

        #expect(command.appName == "Chat")
        #expect(command.template == .aiChat)
        #expect(command.platform == nil)
        #expect(command.outputDirectory.path == "/tmp")
    }

    @Test
    func parseAcceptsPlatformPresetAndGitHubSlug() throws {
        let presetCommand = try NewCommand.parse(
            ArgumentParser(arguments: ["Chat", "--platform", "cloudflare"])
        )
        let slugCommand = try NewCommand.parse(
            ArgumentParser(arguments: ["Chat", "--platform", "1amageek/swift-web-cloudflare"])
        )
        let templatePathCommand = try NewCommand.parse(
            ArgumentParser(arguments: ["Chat", "--platform", "1amageek/swift-web-cloudflare/chat"])
        )
        let presetTemplatePathCommand = try NewCommand.parse(
            ArgumentParser(arguments: ["Chat", "--platform", "cloudflare/chat"])
        )

        #expect(presetCommand.platform?.input == "cloudflare")
        #expect(presetCommand.platform?.preset == "cloudflare")
        #expect(presetCommand.platform?.repositorySlug == "1amageek/swift-web-cloudflare")
        #expect(presetCommand.platform?.repositoryURL == "https://github.com/1amageek/swift-web-cloudflare.git")
        #expect(presetCommand.platform?.templatePath == nil)
        #expect(slugCommand.platform?.input == "1amageek/swift-web-cloudflare")
        #expect(slugCommand.platform?.preset == nil)
        #expect(slugCommand.platform?.repositorySlug == "1amageek/swift-web-cloudflare")
        #expect(slugCommand.platform?.templatePath == nil)
        #expect(templatePathCommand.platform?.repositorySlug == "1amageek/swift-web-cloudflare")
        #expect(templatePathCommand.platform?.templatePath == "chat")
        #expect(presetTemplatePathCommand.platform?.repositorySlug == "1amageek/swift-web-cloudflare")
        #expect(presetTemplatePathCommand.platform?.preset == "cloudflare")
        #expect(presetTemplatePathCommand.platform?.templatePath == "chat")
    }

    @Test
    func aiTemplateCreatesChatFilesAndSwiftWebUIDependency() {
        let project = TemplateProject(
            appName: "Chat",
            projectDirectory: URL(fileURLWithPath: "/tmp/Chat"),
            template: .aiChat
        )
        let files = Dictionary(uniqueKeysWithValues: project.files.map { file in
            (file.path, file.contents)
        })

        #expect(files.keys.contains("Sources/Chat/Routes/ChatPage.swift"))
        #expect(files.keys.contains("Sources/Chat/Components/ChatPanel.swift"))
        #expect(files.keys.contains("Sources/Chat/Components/ChatTheme.swift"))
        #expect(files["Package.swift"]?.contains(".product(name: \"SwiftWebStyle\", package: \"swift-web\")") == true)
        #expect(files["Package.swift"]?.contains(".product(name: \"SwiftWebUI\", package: \"swift-web\")") == true)
        #expect(files["Sources/Chat/App.swift"]?.contains("ChatPage()") == true)
        #expect(files["Sources/Chat/Components/ChatPanel.swift"]?.contains("public struct ChatPanel: ClientComponent") == true)
        #expect(files["Sources/Chat/Components/ChatPanel.swift"]?.contains("sw-chat-composer") == true)
        #expect(files["Sources/Chat/Components/ChatPanel.swift"]?.contains("@State private var turns: [String]") == true)
        #expect(files["Sources/Chat/Components/ChatPanel.swift"]?.contains("ForEach(turns, id: { turn in turn })") == true)
        #expect(files["Sources/Chat/Components/ChatPanel.swift"]?.contains("let nextIndex = turns.count + 1") == true)
        #expect(files["Sources/Chat/Components/ChatPanel.swift"]?.contains("turns = turns + [\"\\(nextIndex):\\(prompt)\"]") == true)
        #expect(files["Sources/Chat/Components/ChatPanel.swift"]?.contains("@State private var entries: [String]") == false)
        #expect(files["Sources/Chat/Components/ChatPanel.swift"]?.contains("entries.append(") == false)
        #expect(files["Sources/Chat/Components/ChatPanel.swift"]?.contains("guard draft != \"\" else") == true)
        #expect(files["Sources/Chat/Components/ChatPanel.swift"]?.contains("allSatisfy(\\\\.isWhitespace)") == false)
        #expect(files["Sources/Chat/Components/ChatPanel.swift"]?.contains("private struct ChatTurn: Sendable, Equatable") == true)
        #expect(files["Sources/Chat/Components/ChatPanel.swift"]?.contains("private enum ChatRole") == false)
        #expect(files["Sources/Chat/Components/ChatPanel.swift"]?.contains("ScrollView(.vertical") == true)
        #expect(files["Sources/Chat/Components/ChatPanel.swift"]?.contains("sw-chat-turn") == true)
        #expect(files["Sources/Chat/Components/ChatPanel.swift"]?.contains("sw-chat-assistant-message") == true)
        #expect(files["Sources/Chat/Components/ChatPanel.swift"]?.contains("sw-chat-user-bubble") == true)
        #expect(files["Sources/Chat/Components/ChatPanel.swift"]?.contains("sw-chat-assistant-label") == false)
        #expect(files["Sources/Chat/Components/ChatPanel.swift"]?.contains("sw-chat-user-label") == false)
        #expect(files["Sources/Chat/Components/ChatPanel.swift"]?.contains("role.label") == false)
        #expect(files["Sources/Chat/Components/ChatPanel.swift"]?.contains("sw-chat-avatar") == false)
        #expect(files["Sources/Chat/Components/ChatPanel.swift"]?.contains("sw-chat-connectors") == false)
        #expect(files["Sources/Chat/Components/ChatPanel.swift"]?.contains("フルアクセス") == false)
        #expect(files["Sources/Chat/Components/ChatTheme.swift"]?.contains("sw-chat-assistant-message") == true)
        #expect(files["Sources/Chat/Components/ChatTheme.swift"]?.contains("sw-chat-user-bubble") == true)
        #expect(files["Sources/Chat/Components/ChatTheme.swift"]?.contains("sw-chat-turn") == true)
        #expect(files["Sources/Chat/Components/ChatTheme.swift"]?.contains("sw-chat-assistant-label") == false)
        #expect(files["Sources/Chat/Components/ChatTheme.swift"]?.contains("sw-chat-user-label") == false)
        #expect(files["Sources/Chat/Components/ChatTheme.swift"]?.contains("sw-chat-avatar") == false)
        #expect(files["Sources/Chat/Components/ChatTheme.swift"]?.contains("sw-chat-connectors") == false)
        #expect(files["Sources/Chat/Components/ChatTheme.swift"]?.contains("StyleRegistry.current") == true)
    }

    @Test
    func minimalTemplateKeepsHomePageOnly() {
        let project = TemplateProject(
            appName: "MyApp",
            projectDirectory: URL(fileURLWithPath: "/tmp/MyApp"),
            template: .minimal
        )
        let paths = Set(project.files.map(\.path))
        let package = project.files.first { $0.path == "Package.swift" }?.contents ?? ""

        #expect(paths.contains("Sources/MyApp/Routes/HomePage.swift"))
        #expect(!paths.contains("Sources/MyApp/Routes/ChatPage.swift"))
        #expect(!paths.contains("Sources/MyApp/Components/ChatPanel.swift"))
        #expect(!paths.contains("Sources/MyApp/Components/ChatTheme.swift"))
        #expect(!paths.contains(".swiftweb/platform.json"))
        #expect(!package.contains(".product(name: \"SwiftWebStyle\", package: \"swift-web\")"))
        #expect(!package.contains(".product(name: \"SwiftWebUI\", package: \"swift-web\")"))
    }

    @Test
    func platformTemplatePinsAdapterReferenceWithoutDeploymentFiles() throws {
        let platform = try PlatformAdapterReference.parse("cloudflare")
        let project = TemplateProject(
            appName: "Chat",
            projectDirectory: URL(fileURLWithPath: "/tmp/Chat"),
            template: .aiChat,
            platform: platform
        )
        let files = Dictionary(uniqueKeysWithValues: project.files.map { file in
            (file.path, file.contents)
        })
        let manifest = try #require(files[".swiftweb/platform.json"])

        #expect(manifest.contains(#""schemaVersion": 1"#))
        #expect(manifest.contains(#""input": "cloudflare""#))
        #expect(manifest.contains(#""source": "github""#))
        #expect(manifest.contains(#""repository": "1amageek/swift-web-cloudflare""#))
        #expect(manifest.contains(#""url": "https://github.com/1amageek/swift-web-cloudflare.git""#))
        #expect(manifest.contains(#""preset": "cloudflare""#))
        #expect(manifest.contains(#""appTemplate": "ai-chat""#))
        #expect(manifest.contains(#""moduleName": "Chat""#))
        #expect(manifest.contains(#""kebabName": "chat""#))
        #expect(files.keys.contains("deploy/cloudflare/wrangler.toml") == false)
        #expect(files.keys.contains("deploy/cloud-run/Dockerfile") == false)
        #expect(files["Package.swift"]?.contains("swift-web-cloudflare") == false)
    }

    @Test
    func platformTemplatePathIsWrittenToManifest() throws {
        let platform = try PlatformAdapterReference.parse("1amageek/swift-web-cloudflare/chat")
        let project = TemplateProject(
            appName: "Chat",
            projectDirectory: URL(fileURLWithPath: "/tmp/Chat"),
            template: .aiChat,
            platform: platform
        )
        let files = Dictionary(uniqueKeysWithValues: project.files.map { file in
            (file.path, file.contents)
        })
        let manifest = try #require(files[".swiftweb/platform.json"])

        #expect(manifest.contains(#""repository": "1amageek/swift-web-cloudflare""#))
        #expect(manifest.contains(#""templatePath": "chat""#))
        #expect(manifest.contains(#""appTemplate": "ai-chat""#))
    }

    @Test
    func platformManifestDecodesTemplateReferenceLinks() throws {
        let manifest = try JSONDecoder().decode(
            PlatformAdapterManifest.self,
            from: Data(
                """
                {
                  "schemaVersion": 1,
                  "id": "cloudflare",
                  "templates": {
                    "new": {
                      "path": "templates/new",
                      "reference": {
                        "title": "SwiftWeb",
                        "url": "https://github.com/1amageek/swift-web"
                      }
                    },
                    "named": {
                      "chat": {
                        "path": "templates/chat",
                        "reference": {
                          "title": "SwiftWeb",
                          "url": "https://github.com/1amageek/swift-web"
                        }
                      }
                    }
                  }
                }
                """.utf8
            )
        )

        #expect(manifest.templates.new?.reference.title == "SwiftWeb")
        #expect(manifest.templates.new?.reference.url == "https://github.com/1amageek/swift-web")
        #expect(manifest.templates.named?["chat"]?.reference.title == "SwiftWeb")
        #expect(manifest.templates.named?["chat"]?.reference.url == "https://github.com/1amageek/swift-web")
    }

    @Test
    func platformMaterializerCopiesNamedTemplateAndRendersPlaceholders() throws {
        try withTemporaryDirectory { root in
            let repository = root.appendingPathComponent("adapter", isDirectory: true)
            let projectDirectory = root.appendingPathComponent("My Chat", isDirectory: true)
            try createAdapterRepository(at: repository)
            try FileManager.default.createDirectory(at: projectDirectory, withIntermediateDirectories: true)

            let platform = try PlatformAdapterReference.parse("1amageek/swift-web-cloudflare/chat")
            let project = TemplateProject(
                appName: "My Chat",
                projectDirectory: projectDirectory,
                template: .aiChat,
                platform: platform
            )
            let materializer = PlatformAdapterTemplateMaterializer(
                repositoryCloner: CopyingPlatformAdapterRepositoryCloner(sourceRepository: repository)
            )

            try materializer.materialize(project: project)

            let wranglerURL = projectDirectory.appendingPathComponent("deploy/cloudflare/wrangler.toml")
            let workerURL = projectDirectory.appendingPathComponent("deploy/cloudflare/src/index.ts")
            let wrangler = try String(contentsOf: wranglerURL, encoding: .utf8)
            let worker = try String(contentsOf: workerURL, encoding: .utf8)

            #expect(wrangler.contains(#"name = "my-chat""#))
            #expect(worker.contains("MyChat"))
            #expect(worker.contains("My Chat"))
        }
    }

    @Test
    func platformMaterializerUsesChatTemplateForAIWhenNoTemplatePathIsPinned() throws {
        try withTemporaryDirectory { root in
            let repository = root.appendingPathComponent("adapter", isDirectory: true)
            let projectDirectory = root.appendingPathComponent("Chat", isDirectory: true)
            try createAdapterRepository(at: repository)
            try FileManager.default.createDirectory(at: projectDirectory, withIntermediateDirectories: true)

            let platform = try PlatformAdapterReference.parse("cloudflare")
            let project = TemplateProject(
                appName: "Chat",
                projectDirectory: projectDirectory,
                template: .aiChat,
                platform: platform
            )
            let materializer = PlatformAdapterTemplateMaterializer(
                repositoryCloner: CopyingPlatformAdapterRepositoryCloner(sourceRepository: repository)
            )

            try materializer.materialize(project: project)

            let wranglerURL = projectDirectory.appendingPathComponent("deploy/cloudflare/wrangler.toml")
            let wrangler = try String(contentsOf: wranglerURL, encoding: .utf8)

            #expect(wrangler.contains(#"name = "chat""#))
        }
    }

    @Test
    func platformMaterializerRejectsAdapterFileOverwrite() throws {
        try withTemporaryDirectory { root in
            let repository = root.appendingPathComponent("adapter", isDirectory: true)
            let projectDirectory = root.appendingPathComponent("Chat", isDirectory: true)
            try createAdapterRepository(at: repository)
            try FileManager.default.createDirectory(
                at: projectDirectory.appendingPathComponent("deploy/cloudflare"),
                withIntermediateDirectories: true
            )
            try "existing".write(
                to: projectDirectory.appendingPathComponent("deploy/cloudflare/wrangler.toml"),
                atomically: true,
                encoding: .utf8
            )

            let platform = try PlatformAdapterReference.parse("cloudflare/chat")
            let project = TemplateProject(
                appName: "Chat",
                projectDirectory: projectDirectory,
                template: .aiChat,
                platform: platform
            )
            let materializer = PlatformAdapterTemplateMaterializer(
                repositoryCloner: CopyingPlatformAdapterRepositoryCloner(sourceRepository: repository)
            )

            do {
                try materializer.materialize(project: project)
                Issue.record("Expected platform materialization to reject an overwrite")
            } catch let error as CLIError {
                #expect(error.message.contains("would overwrite"))
                #expect(error.exitCode == 73)
            } catch {
                Issue.record("Expected CLIError, got \(error)")
            }
        }
    }

    @Test
    func appTypeNameUsesSwiftIdentifier() {
        let lowercaseProject = TemplateProject(
            appName: "chat",
            projectDirectory: URL(fileURLWithPath: "/tmp/chat"),
            template: .aiChat
        )
        let dashedProject = TemplateProject(
            appName: "my-chat",
            projectDirectory: URL(fileURLWithPath: "/tmp/my-chat"),
            template: .minimal
        )
        let camelProject = TemplateProject(
            appName: "RemoteChat",
            projectDirectory: URL(fileURLWithPath: "/tmp/RemoteChat"),
            template: .minimal
        )

        let lowercaseFiles = Dictionary(uniqueKeysWithValues: lowercaseProject.files.map { file in
            (file.path, file.contents)
        })
        let dashedFiles = Dictionary(uniqueKeysWithValues: dashedProject.files.map { file in
            (file.path, file.contents)
        })
        let lowercasePackage = lowercaseFiles["Package.swift"] ?? ""
        let dashedPackage = dashedFiles["Package.swift"] ?? ""
        let lowercaseApp = lowercaseFiles["Sources/Chat/App.swift"] ?? ""
        let dashedApp = dashedFiles["Sources/MyChat/App.swift"] ?? ""

        #expect(lowercaseApp.contains("public struct Chat: SwiftWeb.App"))
        #expect(dashedApp.contains("public struct MyChat: SwiftWeb.App"))
        #expect(lowercasePackage.contains("name: \"Chat\""))
        #expect(dashedPackage.contains("name: \"MyChat\""))
        #expect(camelProject.moduleName == "RemoteChat")
        #expect(camelProject.kebabName == "remote-chat")
    }
}

private struct CopyingPlatformAdapterRepositoryCloner: PlatformAdapterRepositoryCloning {
    let sourceRepository: URL

    func clone(_ reference: PlatformAdapterReference, to checkoutDirectory: URL) throws {
        try FileManager.default.copyItem(at: sourceRepository, to: checkoutDirectory)
    }
}

private func withTemporaryDirectory(_ body: (URL) throws -> Void) throws {
    let directory = FileManager.default.temporaryDirectory
        .appendingPathComponent("swiftweb-cli-tests-\(UUID().uuidString)", isDirectory: true)
    try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    do {
        try body(directory)
        try FileManager.default.removeItem(at: directory)
    } catch {
        removeTemporaryDirectoryIfPresent(directory)
        throw error
    }
}

private func removeTemporaryDirectoryIfPresent(_ directory: URL) {
    guard FileManager.default.fileExists(atPath: directory.path) else {
        return
    }
    do {
        try FileManager.default.removeItem(at: directory)
    } catch {
        Issue.record("Failed to remove temporary directory \(directory.path): \(error)")
    }
}

private func createAdapterRepository(at repository: URL) throws {
    let fileManager = FileManager.default
    try fileManager.createDirectory(
        at: repository.appendingPathComponent("templates/chat/deploy/cloudflare/src", isDirectory: true),
        withIntermediateDirectories: true
    )
    try """
    {
      "schemaVersion": 1,
      "id": "cloudflare",
      "name": "SwiftWeb Cloudflare",
        "templates": {
          "new": {
            "path": "templates/new",
            "reference": {
              "title": "SwiftWeb",
              "url": "https://github.com/1amageek/swift-web"
            }
          },
          "named": {
            "chat": {
              "path": "templates/chat",
              "reference": {
                "title": "SwiftWeb",
                "url": "https://github.com/1amageek/swift-web"
              }
            }
          }
        },
      "capabilities": {
        "scaffold": true,
        "build": false,
        "deploy": false
      }
    }
    """.write(
        to: repository.appendingPathComponent("sweb.json"),
        atomically: true,
        encoding: .utf8
    )
    try """
    name = "{{app.kebabName}}"
    main = "src/index.ts"
    """.write(
        to: repository.appendingPathComponent("templates/chat/deploy/cloudflare/wrangler.toml"),
        atomically: true,
        encoding: .utf8
    )
    try """
    export default {
      fetch() {
        return new Response("{{app.moduleName}}: {{app.name}}")
      }
    }
    """.write(
        to: repository.appendingPathComponent("templates/chat/deploy/cloudflare/src/index.ts"),
        atomically: true,
        encoding: .utf8
    )
}
