import Foundation
import XCTest
@testable import SwiftWebCLI

final class NewCommandTemplateTests: XCTestCase {
    func testParseAcceptsAIFlag() throws {
        let command = try NewCommand.parse(
            ArgumentParser(arguments: ["Chat", "--ai", "--output", "/tmp"])
        )

        XCTAssertEqual(command.appName, "Chat")
        XCTAssertEqual(command.template, .aiChat)
        XCTAssertNil(command.adapter)
        XCTAssertEqual(command.outputDirectory.path, "/tmp")
    }

    func testParseAcceptsAdapterGitHubRepository() throws {
        let repository = try NewCommand.parse(
            ArgumentParser(arguments: ["Chat", "--adapter", "1amageek/swift-web-cloudflare"])
        )

        XCTAssertEqual(repository.adapter?.repositorySlug, "1amageek/swift-web-cloudflare")
        XCTAssertEqual(repository.adapter?.adapterID, "swift-web-cloudflare")
    }

    func testParseRejectsAdapterTemplatePaths() {
        do {
            _ = try NewCommand.parse(
                ArgumentParser(arguments: ["Chat", "--adapter", "cloudflare/chat/worker"])
            )
            XCTFail("Expected a package reference, not an adapter template path")
        } catch let error as CLIError {
            XCTAssertEqual(error.exitCode, 64)
        } catch {
            XCTFail("Expected CLIError, got \(error)")
        }
    }

    func testAITemplateCreatesChatFilesAndSwiftWebUIDependency() {
        let project = TemplateProject(
            appName: "Chat",
            projectDirectory: URL(fileURLWithPath: "/tmp/Chat"),
            template: .aiChat
        )
        let files = Dictionary(uniqueKeysWithValues: project.files.map { file in
            (file.path, file.contents)
        })

        XCTAssertTrue(files.keys.contains("Sources/Chat/Routes/ChatPage.swift"))
        XCTAssertTrue(files.keys.contains("Sources/Chat/Components/ChatPanel.swift"))
        XCTAssertTrue(files.keys.contains("Sources/Chat/Components/ChatTheme.swift"))
        XCTAssertTrue(files["Package.swift"]?.contains(
            ".product(name: \"SwiftWebStyle\", package: \"swift-web\")"
        ) == true)
        XCTAssertTrue(files["Package.swift"]?.contains(
            ".product(name: \"SwiftWebUI\", package: \"swift-web\")"
        ) == true)
        XCTAssertTrue(files["Package.swift"]?.contains(
            #".package(url: "https://github.com/1amageek/swift-html.git", from: "0.15.0")"#
        ) == true)
        XCTAssertTrue(files["Package.swift"]?.contains(
            #".package(url: "https://github.com/1amageek/swift-web.git", from: "0.11.0")"#
        ) == true)
        XCTAssertTrue(files["Sources/Chat/App.swift"]?.contains("ChatPage()") == true)
        XCTAssertTrue(files["Sources/Chat/Components/ChatPanel.swift"]?.contains(
            "public struct ChatPanel: ClientComponent {"
        ) == true)
        XCTAssertTrue(files["Sources/Chat/Components/ChatPanel.swift"]?.contains("sw-chat-composer") == true)
        XCTAssertTrue(files["Sources/Chat/Components/ChatPanel.swift"]?.contains(
            "@State private var turns: [String]"
        ) == true)
        XCTAssertTrue(files["Sources/Chat/Components/ChatPanel.swift"]?.contains(
            "ForEach(turns, id: { turn in turn })"
        ) == true)
        XCTAssertTrue(files["Sources/Chat/Components/ChatPanel.swift"]?.contains(
            "turns = turns + [\"\\(nextIndex):\\(prompt)\"]"
        ) == true)
        XCTAssertFalse(files["Sources/Chat/Components/ChatPanel.swift"]?.contains("entries.append(") == true)
        XCTAssertTrue(files["Sources/Chat/Components/ChatPanel.swift"]?.contains(
            "private struct ChatTurn: Sendable, Equatable"
        ) == true)
        XCTAssertTrue(files["Sources/Chat/Components/ChatPanel.swift"]?.contains("ScrollView(.vertical") == true)
        XCTAssertTrue(files["Sources/Chat/Components/ChatPanel.swift"]?.contains("sw-chat-turn") == true)
        XCTAssertTrue(files["Sources/Chat/Components/ChatPanel.swift"]?.contains(
            "sw-chat-assistant-message"
        ) == true)
        XCTAssertTrue(files["Sources/Chat/Components/ChatPanel.swift"]?.contains("sw-chat-user-bubble") == true)
        XCTAssertFalse(files["Sources/Chat/Components/ChatPanel.swift"]?.contains("sw-chat-avatar") == true)
        XCTAssertTrue(files["Sources/Chat/Components/ChatTheme.swift"]?.contains(
            "sw-chat-assistant-message"
        ) == true)
        XCTAssertTrue(files["Sources/Chat/Components/ChatTheme.swift"]?.contains("sw-chat-user-bubble") == true)
        XCTAssertTrue(files["Sources/Chat/Components/ChatTheme.swift"]?.contains("StyleRegistry.current") == true)
    }

    func testGeneratedProjectDeclaresAdaptersAndSourceControlledEnvironments() throws {
        let adapter = try AdapterPackageReference.parse("1amageek/swift-web-cloudflare")
        let project = TemplateProject(
            appName: "My Chat",
            projectDirectory: URL(fileURLWithPath: "/tmp/My Chat"),
            template: .aiChat,
            adapter: adapter
        )
        let files = Dictionary(uniqueKeysWithValues: project.files.map { ($0.path, $0.contents) })
        let package = try XCTUnwrap(files["Package.swift"])
        let manifest = try XCTUnwrap(files["sweb.json"])

        XCTAssertTrue(package.contains(#".package(url: "https://github.com/1amageek/swift-web.git", from: "0.11.0")"#))
        XCTAssertTrue(package.contains(#".package(url: "https://github.com/1amageek/swift-web-cloudflare.git", branch: "main")"#))
        XCTAssertTrue(package.contains("swift-web-cloudflare"))
        XCTAssertFalse(files.keys.contains(".swiftweb/platform.json"))
        XCTAssertTrue(manifest.contains(#""host": "swift-web/http-server""#))
        XCTAssertTrue(manifest.contains(#""host": "swift-web-cloudflare""#))
        XCTAssertTrue(manifest.contains(#""deployment": "swift-web-cloudflare""#))

        let decoded = try JSONDecoder().decode(
            SwiftWebProjectManifest.self,
            from: Data(manifest.utf8)
        )
        XCTAssertEqual(decoded.application.product, "MyChat")
        XCTAssertEqual(decoded.defaults.dev, "local")
        XCTAssertEqual(decoded.defaults.deploy, "production")
    }

    func testMinimalTemplateUsesSwiftIdentifiersWithoutUIProducts() {
        let project = TemplateProject(
            appName: "my-chat",
            projectDirectory: URL(fileURLWithPath: "/tmp/my-chat"),
            template: .minimal
        )
        let files = Dictionary(uniqueKeysWithValues: project.files.map { ($0.path, $0.contents) })
        let paths = Set(files.keys)
        let package = files["Package.swift"] ?? ""
        let app = files["Sources/MyChat/App.swift"] ?? ""

        XCTAssertTrue(paths.contains("Sources/MyChat/Routes/HomePage.swift"))
        XCTAssertFalse(paths.contains("Sources/MyChat/Routes/ChatPage.swift"))
        XCTAssertFalse(paths.contains("Sources/MyChat/Components/ChatPanel.swift"))
        XCTAssertFalse(paths.contains("Sources/MyChat/Components/ChatTheme.swift"))
        XCTAssertFalse(paths.contains(".swiftweb/platform.json"))
        XCTAssertTrue(app.contains("public struct MyChat: SwiftWeb.App"))
        XCTAssertFalse(package.contains("SwiftWebStyle"))
        XCTAssertFalse(package.contains("SwiftWebUI\""))
        XCTAssertTrue(package.contains(
            #".package(url: "https://github.com/1amageek/swift-html.git", from: "0.15.0")"#
        ))
        XCTAssertTrue(package.contains(
            #".package(url: "https://github.com/1amageek/swift-web.git", from: "0.11.0")"#
        ))
        XCTAssertEqual(project.moduleName, "MyChat")
        XCTAssertEqual(project.kebabName, "my-chat")
    }

    func testAppTypeNameUsesSwiftIdentifier() {
        let lowercaseProject = TemplateProject(
            appName: "chat",
            projectDirectory: URL(fileURLWithPath: "/tmp/chat"),
            template: .aiChat
        )
        let camelProject = TemplateProject(
            appName: "RemoteChat",
            projectDirectory: URL(fileURLWithPath: "/tmp/RemoteChat"),
            template: .minimal
        )
        let lowercaseFiles = Dictionary(
            uniqueKeysWithValues: lowercaseProject.files.map { ($0.path, $0.contents) }
        )
        let lowercasePackage = lowercaseFiles["Package.swift"] ?? ""
        let lowercaseApp = lowercaseFiles["Sources/Chat/App.swift"] ?? ""

        XCTAssertTrue(lowercaseApp.contains("public struct Chat: SwiftWeb.App"))
        XCTAssertTrue(lowercasePackage.contains("name: \"Chat\""))
        XCTAssertEqual(camelProject.moduleName, "RemoteChat")
        XCTAssertEqual(camelProject.kebabName, "remote-chat")
    }
}
