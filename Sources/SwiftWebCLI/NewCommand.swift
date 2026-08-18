import Foundation
import SwiftWebDevelopment

struct NewCommand {
    let appName: String
    let outputDirectory: URL
    let force: Bool
    let template: TemplateKind
    let adapter: AdapterPackageReference?

    static func parse(_ parser: ArgumentParser) throws -> NewCommand {
        var parser = parser
        guard let appName = parser.next(), !appName.hasPrefix("--") else {
            throw CLIError(message: "missing app name", exitCode: 64)
        }

        var outputDirectory = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
        var force = false
        var template = TemplateKind.minimal
        var adapter: AdapterPackageReference?

        while let option = parser.next() {
            switch option {
            case "--output":
                outputDirectory = URL(fileURLWithPath: try parser.requireValue(after: option))
            case "--force":
                force = true
            case "--ai":
                template = .aiChat
            case "--adapter":
                adapter = try AdapterPackageReference.parse(try parser.requireValue(after: option))
            default:
                throw CLIError(message: "unknown option: \(option)", exitCode: 64)
            }
        }

        return NewCommand(
            appName: appName,
            outputDirectory: outputDirectory,
            force: force,
            template: template,
            adapter: adapter
        )
    }

    func run() async throws {
        let projectDirectory = outputDirectory
            .appendingPathComponent(appName, isDirectory: true)
            .standardizedFileURL
        let project = TemplateProject(
            appName: appName,
            projectDirectory: projectDirectory,
            template: template,
            adapter: adapter
        )

        progress("Scaffolding \(appName) at \(projectDirectory.path)")
        try createDirectory(projectDirectory)
        for file in project.files {
            try write(file, to: projectDirectory)
        }

        progress("Resolving dependencies and materializing environments (first run downloads dependencies, this can take a minute)")
        try await SwiftWebProjectLifecycle(
            packageDirectory: projectDirectory,
            environmentOverride: nil,
            hostOverride: nil,
            portOverride: nil,
            wasmRuntimeProfile: .standard
        )
        .run(.prepare)

        print("Created \(project.directoryName) at \(projectDirectory.path)")
    }

    /// Emit a step notice to stderr, flushed immediately so a long-running step
    /// (dependency resolution) never leaves the CLI looking frozen.
    private func progress(_ message: String) {
        FileHandle.standardError.write(Data("→ \(message)\n".utf8))
    }

    private func createDirectory(_ url: URL) throws {
        let fileManager = FileManager.default
        if fileManager.fileExists(atPath: url.path) {
            if force {
                try fileManager.removeItem(at: url)
            } else {
                throw CLIError(message: "directory already exists: \(url.path)", exitCode: 73)
            }
        }
        try fileManager.createDirectory(at: url, withIntermediateDirectories: true)
    }

    private func write(_ file: TemplateFile, to projectDirectory: URL) throws {
        let url = projectDirectory.appendingPathComponent(file.path)
        let parent = url.deletingLastPathComponent()
        try FileManager.default.createDirectory(at: parent, withIntermediateDirectories: true)
        try file.contents.write(to: url, atomically: true, encoding: .utf8)
        if file.isExecutable {
            try FileManager.default.setAttributes([.posixPermissions: 0o755], ofItemAtPath: url.path)
        }
    }
}

enum TemplateKind: Equatable {
    case minimal
    case aiChat
}

struct AdapterPackageReference: Equatable {
    let input: String
    let repositorySlug: String

    var repositoryURL: String {
        "https://github.com/\(repositorySlug).git"
    }

    var adapterID: String {
        repositorySlug.split(separator: "/").last.map(String.init) ?? repositorySlug
    }

    var packageDependencyDeclaration: String {
        return #".package(url: "\#(repositoryURL)", branch: "main")"#
    }

    static func parse(_ value: String) throws -> AdapterPackageReference {
        let normalized = value.trimmingCharacters(in: Foundation.CharacterSet.whitespacesAndNewlines)
        guard !normalized.isEmpty else {
            throw CLIError(message: "missing value for --adapter", exitCode: 64)
        }

        if let repositorySlug = githubSlug(from: normalized) {
            return AdapterPackageReference(
                input: normalized,
                repositorySlug: repositorySlug
            )
        }

        throw CLIError(
            message: "invalid value for --adapter: \(value) (expected GitHub owner/repository)",
            exitCode: 64
        )
    }

    private static func githubSlug(from value: String) -> String? {
        var candidate = value

        if candidate.hasPrefix("github:") {
            candidate.removeFirst("github:".count)
        } else if candidate.hasPrefix("https://github.com/") {
            candidate.removeFirst("https://github.com/".count)
        } else if candidate.hasPrefix("git@github.com:") {
            candidate.removeFirst("git@github.com:".count)
        }

        if candidate.hasSuffix(".git") {
            candidate.removeLast(".git".count)
        }

        let parts = candidate.split(separator: "/", omittingEmptySubsequences: true).map(String.init)
        guard parts.count == 2 else {
            return nil
        }
        guard Self.isValidPathParts(parts) else {
            return nil
        }

        return (parts.joined(separator: "/"))
    }

    private static func isValidPathParts<Parts: Collection>(_ parts: Parts) -> Bool
    where Parts.Element == String {
        parts.allSatisfy { part in
            !part.isEmpty && part.allSatisfy { character in
                character.isLetter || character.isNumber || character == "-" || character == "_" || character == "."
            }
        }
    }
}

struct TemplateFile {
    let path: String
    let contents: String
    let isExecutable: Bool

    init(path: String, contents: String, isExecutable: Bool = false) {
        self.path = path
        self.contents = contents
        self.isExecutable = isExecutable
    }
}

struct TemplateProject {
    let appName: String
    let projectDirectory: URL
    let template: TemplateKind
    let adapter: AdapterPackageReference?

    init(
        appName: String,
        projectDirectory: URL,
        template: TemplateKind,
        adapter: AdapterPackageReference? = nil
    ) {
        self.appName = appName
        self.projectDirectory = projectDirectory
        self.template = template
        self.adapter = adapter
    }

    var directoryName: String {
        appName
    }

    var files: [TemplateFile] {
        var files = [
            TemplateFile(path: "Package.swift", contents: packageSwift),
            TemplateFile(path: "README.md", contents: readme),
            TemplateFile(path: "Sources/\(appTypeName)/App.swift", contents: appSwift),
            TemplateFile(path: "Sources/\(appTypeName)/Routes/\(pageFileName)", contents: pageSwift),
        ]
        files.append(TemplateFile(path: "sweb.json", contents: projectManifest))
        if template == .aiChat {
            files.append(
                TemplateFile(
                    path: "Sources/\(appTypeName)/Components/ChatPanel.swift",
                    contents: chatPanelSwift
                )
            )
            files.append(
                TemplateFile(
                    path: "Sources/\(appTypeName)/Components/ChatTheme.swift",
                    contents: chatThemeSwift
                )
            )
        }
        return files
    }

    private var pageTypeName: String {
        switch template {
        case .minimal:
            "HomePage"
        case .aiChat:
            "ChatPage"
        }
    }

    private var pageFileName: String {
        "\(pageTypeName).swift"
    }

    private var appTypeName: String {
        appName.swiftTypeIdentifier(defaultName: "App")
    }

    var moduleName: String {
        appTypeName
    }

    var kebabName: String {
        appName.kebabIdentifier(defaultName: "app")
    }

    private var packageSwift: String {
        """
        // swift-tools-version: 6.4

        import PackageDescription

        let package = Package(
            name: "\(appTypeName)",
            platforms: [
                .macOS("26.2"),
            ],
            products: [
                .library(name: "\(appTypeName)", targets: ["\(appTypeName)"]),
            ],
            dependencies: [
                \(SwiftWebPackageReference.packageDependencyDeclaration),
                .package(url: "https://github.com/1amageek/swift-html.git", from: "0.15.0"),
        \(adapterPackageDependencyLine)
            ],
            targets: [
                .target(
                    name: "\(appTypeName)",
                    dependencies: [
        \(targetDependencyLines)
                    ],
                    swiftSettings: [
                        .enableUpcomingFeature("ApproachableConcurrency"),
                    ]
                ),
            ],
            swiftLanguageModes: [.v6]
        )
        """
    }

    private var targetDependencyLines: String {
        var lines = [
            "                .product(name: \"SwiftHTML\", package: \"swift-html\"),",
            "                .product(name: \"SwiftWeb\", package: \"swift-web\"),",
        ]
        if template == .aiChat {
            lines.append("                .product(name: \"SwiftWebStyle\", package: \"swift-web\"),")
            lines.append("                .product(name: \"SwiftWebUI\", package: \"swift-web\"),")
        }
        return lines.joined(separator: "\n")
    }

    private var readme: String {
        """
        # \(appTypeName)

        Generated by SwiftWeb.

        Run from Terminal:

        ```bash
        sweb dev
        ```

        \(templateSummary)

        \(adapterSummary)

        Host and deployment adapters are resolved from `Package.swift` dependencies
        through the source-controlled `sweb.json` environment configuration.

        \(adapterUsage)


        Run from Xcode:

        ```text
        Open .swiftweb/generated/dev in Xcode and select the \(appTypeName)-dev scheme.
        ```

        Build server:

        ```bash
        sweb build
        ```

        `Package.swift` declares the app library and adapter package sources. Generated
        launchers and deployment workspaces remain under `.swiftweb/generated`.
        """
    }

    private var templateSummary: String {
        switch template {
        case .minimal:
            ""
        case .aiChat:
            """

            This app was generated with `--ai`. It includes a chat-first UI and a client-side composer. Connect `ChatPanel` to a server action or distributed actor when you add a provider.
            """
        }
    }

    private var adapterSummary: String {
        guard let adapter else {
            return "No additional Host or Deployment adapter is applied yet."
        }

        return """
        Adapter package:

        | Field | Value |
        |---|---|
        | Reference | `\(adapter.input)` |
        | Repository | `\(adapter.repositorySlug)` |
        | URL | `\(adapter.repositoryURL)` |
        | Adapter | `\(adapter.adapterID)` |
        """
    }

    private var adapterUsage: String {
        guard adapter != nil else {
            return """
            Pass `--adapter <github-owner/repository>` to add a Host or Deployment adapter package when creating a project.
            """
        }

        return """
        `sweb` resolves the adapter from the SwiftPM package graph. No adapter checkout
        or adapter-specific installer command is required.
        """
    }

    private var projectManifest: String {
        let productionEnvironment: String
        let defaults: String
        if let adapter {
            productionEnvironment = """
                ,
                    "production": {
                      "host": "\(adapter.adapterID.jsonEscaped)",
                      "deployment": "\(adapter.adapterID.jsonEscaped)",
                      "overlays": [],
                      "operations": {}
                    }
            """
            defaults = """
                "build": "production",
                    "dev": "local",
                    "deploy": "production"
            """
        } else {
            productionEnvironment = ""
            defaults = """
                "build": "local",
                    "dev": "local",
                    "deploy": null
            """
        }
        return """
        {
          "schemaVersion": 2,
          "application": {
            "product": "\(appTypeName.jsonEscaped)",
            "module": "\(appTypeName.jsonEscaped)",
            "type": "\(appTypeName.jsonEscaped)"
          },
          "environments": {
            "local": {
              "host": "swift-web/http-server",
              "deployment": "swift-web/local",
              "overlays": [],
              "operations": {}
            }\(productionEnvironment)
          },
          "defaults": {
            \(defaults)
          }
        }
        """
    }

    private var adapterPackageDependencyLine: String {
        guard let adapter else {
            return ""
        }
        return "            \(adapter.packageDependencyDeclaration),"
    }

    private var appSwift: String {
        """
        import SwiftWeb

        public struct \(appTypeName): SwiftWeb.App {
            public init() {}

            public var body: some Scene {
                \(pageTypeName)()
            }
        }
        """
    }

    private var pageSwift: String {
        switch template {
        case .minimal:
            minimalPageSwift
        case .aiChat:
            chatPageSwift
        }
    }

    private var minimalPageSwift: String {
        """
        import SwiftHTML
        import SwiftWeb

        @Page("/")
        struct HomePage {
            var document: some HTMLDocument {
                PageDocument(
                    title: "Hello World",
                    description: "A SwiftWeb page rendered with SwiftHTML."
                ) {
                    main {
                        h1 { "Hello World" }
                        p { "Rendered by SwiftWeb." }
                    }
                }
            }
        }

        #Preview {
            HomePage().document.body
        }
        """
    }

    private var chatPageSwift: String {
        """
        import SwiftHTML
        import SwiftWeb
        import SwiftWebUI

        @Page("/")
        struct ChatPage {
            var document: some HTMLDocument {
                PageDocument(
                    title: "AI Chat",
                    description: "A SwiftWeb chat interface ready for an AI provider."
                ) {
                    main {
                        ChatTheme {
                            div(.class("sw-chat-shell")) {
                                h1(.class("sw-chat-title")) {
                                    "swift-web で何を作りましょうか?"
                                }

                                ChatPanel()
                            }
                        }
                    }
                    .preferredColorScheme(.dark)
                }
            }
        }

        #Preview {
            ChatPage().document.body
        }
        """
    }

    private var chatPanelSwift: String {
        """
        import SwiftHTML
        import SwiftWebUI

        public struct ChatPanel: ClientComponent {
            @State private var draft = ""
            @State private var turns: [String] = [
                "1:チャットの UI を作りたい。",
            ]

            public init() {}

            public var content: some Component {
                VStack(alignment: .stretch, spacing: .large) {
                    ScrollView(.vertical, showsIndicators: false) {
                        VStack(alignment: .stretch, spacing: .small) {
                            assistantMessage(Self.openingMessage)

                            ForEach(turns, id: { turn in turn }) { turn in
                                turnRow(ChatTurn(encodedValue: turn))
                            }
                        }
                        .class("sw-chat-thread-stack")
                    }
                    .class("sw-chat-thread")

                    HStack(alignment: .bottom, spacing: .small) {
                        TextEditor(text: $draft, .placeholder("何でもできます"))
                            .class("sw-chat-textarea")
                            .accessibilityLabel("Message")

                        Button(action: {
                            sendDraft()
                        }) {
                            Text("↑").as(.span)
                                .class("sw-chat-send-icon")
                        }
                        .class("sw-chat-send")
                        .accessibilityLabel("Send message")
                    }
                    .class("sw-chat-composer")
                }
                .class("sw-chat-panel")
            }

            private func sendDraft() {
                guard draft != "" else {
                    return
                }

                let prompt = draft
                let nextIndex = turns.count + 1
                turns = turns + ["\\(nextIndex):\\(prompt)"]
                draft = ""
            }

            private func turnRow(_ turn: ChatTurn) -> some Component {
                VStack(alignment: .stretch, spacing: .small) {
                    userMessage(turn.prompt)
                    assistantMessage(Self.responseMessage)
                }
                .class("sw-chat-turn")
            }

            private func assistantMessage(_ text: String) -> some Component {
                HStack(alignment: .bottom, spacing: .small) {
                    VStack(alignment: .leading, spacing: 0) {
                        Text(text)
                            .class("sw-chat-assistant-message")
                    }
                    .class("sw-chat-assistant-stack")
                }
                .class("sw-chat-message sw-chat-message-assistant")
            }

            private func userMessage(_ text: String) -> some Component {
                HStack(alignment: .bottom, spacing: .small) {
                    VStack(alignment: .trailing, spacing: 0) {
                        Text(text)
                            .class("sw-chat-user-bubble")
                    }
                    .class("sw-chat-user-stack")
                }
                .class("sw-chat-message sw-chat-message-user")
            }

            private struct ChatTurn: Sendable, Equatable {
                var prompt: String

                init(encodedValue: String) {
                    let parts = encodedValue.split(separator: ":", maxSplits: 1, omittingEmptySubsequences: false)
                    self.prompt = parts.count == 2 ? String(parts[1]) : encodedValue
                }
            }

            private static let openingMessage = "SwiftWebUI のコンポーネントで、会話しながら画面を作れます。"
            private static let responseMessage = "受け取りました。次はこの会話を ServerAction や Actor に接続できます。"
        }
        """
    }

    private var chatThemeSwift: String {
        """
        import SwiftHTML
        import SwiftWebStyle

        struct ChatTheme<Content: Component>: Component {
            private let childContent: Content

            init(@HTMLBuilder _ content: () -> Content) {
                self.childContent = content()
            }

            @ComponentBuilder
            var content: some Component {
                if let registry = StyleRegistry.current {
                    let _ = registry.registerStylesheet(Self.stylesheet.cssText)
                    EmptyHTML()
                } else {
                    style {
                        rawHTML(Self.stylesheet.cssText)
                    }
                }

                div(.class("sw-chat-root")) {
                    childContent
                }
            }

            private static func cls(_ name: String) -> StyleSelector {
                .class(StyleClass(name))
            }

            private static var stylesheet: Stylesheet {
                Stylesheet {
                    rule(.element(.html)) {
                        .backgroundColor("#171923")
                    }
                    rule(.element(.body)) {
                        .margin("0")
                          .backgroundColor("#171923")
                    }
                    rule(cls("sw-chat-root")) {
                        .minHeight("100vh")
                          .boxSizing("border-box")
                          .display("flex")
                          .alignItems("center")
                          .justifyContent("center")
                          .padding("56px 24px")
                          .background("radial-gradient(circle at 50% 20%, rgba(96, 108, 151, 0.18), transparent 34%), #171923")
                          .color("#e7ebff")
                          .fontFamily("-apple-system, BlinkMacSystemFont, 'SF Pro Display', 'SF Pro Text', sans-serif")
                    }
                    rule(cls("sw-chat-shell")) {
                        .width("min(100%, 760px)")
                          .height("min(760px, calc(100vh - 112px))")
                          .display("grid")
                          .gridTemplateRows("auto minmax(0, 1fr)")
                          .gap("28px")
                    }
                    rule(cls("sw-chat-title")) {
                        .margin("0")
                          .textAlign("center")
                          .fontSize("28px")
                          .lineHeight("1.2")
                          .fontWeight("450")
                          .letterSpacing("0")
                          .color("#b9bfdf")
                    }
                    rule(cls("sw-chat-panel")) {
                        .minHeight("0")
                          .display("grid")
                          .gridTemplateRows("minmax(0, 1fr) auto")
                          .gap("16px")
                    }
                    rule(cls("sw-chat-thread")) {
                        .minHeight("0")
                          .boxSizing("border-box")
                          .padding("20px")
                          .border("1px solid rgba(121, 128, 164, 0.14)")
                          .borderRadius("24px")
                          .background("rgba(20, 23, 35, 0.54)")
                          .boxShadow("0 28px 80px rgba(0, 0, 0, 0.28)")
                    }
                    rule(cls("sw-chat-thread-stack")) {
                        .minHeight("100%")
                          .justifyContent("flex-end")
                    }
            rule(cls("sw-chat-message")) {
                .width("100%")
            }
            rule(cls("sw-chat-turn")) {
                .width("100%")
            }
            rule(cls("sw-chat-message-user")) {
                .justifyContent("flex-end")
            }
                    rule(cls("sw-chat-message-assistant")) {
                        .justifyContent("flex-start")
                    }
                    rule(cls("sw-chat-assistant-stack")) {
                        .width("100%")
                    }
                    rule(cls("sw-chat-user-stack")) {
                        .maxWidth("min(68%, 520px)")
                    }
            rule(cls("sw-chat-assistant-message")) {
                .margin("0")
                  .width("100%")
                          .boxSizing("border-box")
                          .color("#e9edff")
                          .fontSize("15px")
                          .lineHeight("1.65")
                    }
            rule(cls("sw-chat-user-bubble")) {
                .margin("0")
                  .boxSizing("border-box")
                          .padding("12px 14px")
                          .border("1px solid rgba(116, 143, 255, 0.28)")
                          .borderRadius("18px")
                          .background("linear-gradient(180deg, rgba(82, 96, 150, 0.92), rgba(58, 66, 106, 0.92))")
                          .color("#e9edff")
                          .fontSize("15px")
                          .lineHeight("1.5")
                    }
                    rule(cls("sw-chat-composer")) {
                        .boxSizing("border-box")
                          .padding("10px")
                          .border("1px solid rgba(121, 128, 164, 0.18)")
                          .borderRadius("24px")
                          .background("linear-gradient(180deg, rgba(44, 47, 65, 0.98), rgba(38, 41, 58, 0.98))")
                          .boxShadow("0 24px 80px rgba(0, 0, 0, 0.36)")
                    }
                    rule(cls("sw-chat-composer").pseudo(.focusWithin)) {
                        .borderColor("rgba(166, 174, 218, 0.28)")
                          .boxShadow("0 28px 90px rgba(0, 0, 0, 0.42), 0 0 0 1px rgba(180, 188, 230, 0.08)")
                    }
                    rule(cls("sw-chat-textarea")) {
                        .minHeight("48px")
                          .maxHeight("160px")
                          .width("100%")
                          .boxSizing("border-box")
                          .resize("vertical")
                          .border("0")
                          .borderRadius("16px")
                          .padding("13px 14px")
                          .background("rgba(15, 18, 28, 0.38)")
                          .boxShadow("none")
                          .outline("none")
                          .color("#ecefff")
                          .fontSize("15px")
                          .lineHeight("1.45")
                    }
                    rule(cls("sw-chat-textarea").pseudoElement(.placeholder)) {
                        .color("#6d728c")
                    }
                    rule(cls("sw-chat-send")) {
                        .width("42px")
                          .height("42px")
                          .minWidth("42px")
                          .padding("0")
                          .display("inline-grid")
                          .placeItems("center")
                          .border("0")
                          .borderRadius("999px")
                          .background("#a8b1d8")
                          .color("#202437")
                          .boxShadow("none")
                    }
                    rule(cls("sw-chat-send").pseudo(.hover)) {
                        .background("#c0c8eb")
                          .transform("translateY(-1px)")
                    }
                    rule(cls("sw-chat-send-icon")) {
                        .fontSize("21px")
                          .fontWeight("800")
                          .lineHeight("1")
                    }
                    media(StyleMediaQuery.maxWidth("720px")) {
                        rule(cls("sw-chat-root")) {
                            .padding("32px 14px")
                        }
                        rule(cls("sw-chat-shell")) {
                            .height("calc(100vh - 64px)")
                              .gap("20px")
                        }
                        rule(cls("sw-chat-title")) {
                            .fontSize("23px")
                        }
                        rule(cls("sw-chat-thread")) {
                            .padding("14px")
                              .borderRadius("20px")
                        }
                        rule(cls("sw-chat-user-stack")) {
                            .maxWidth("78%")
                        }
                    }
                }
            }
        }
        """
    }

}

private extension String {
    func swiftTypeIdentifier(defaultName: String) -> String {
        let components = split { character in
            !character.isLetter && !character.isNumber
        }
        let identifier = components
            .map { component in
                let text = String(component)
                guard let first = text.first else {
                    return ""
                }
                return first.uppercased() + text.dropFirst()
            }
            .joined()

        let fallback = identifier.isEmpty ? defaultName : identifier
        guard let first = fallback.first, first.isLetter || first == "_" else {
            return defaultName + fallback
        }
        return fallback
    }

    func kebabIdentifier(defaultName: String) -> String {
        var components: [String] = []
        var current = ""
        for character in self {
            guard character.isLetter || character.isNumber else {
                if !current.isEmpty {
                    components.append(current)
                    current = ""
                }
                continue
            }

            if character.isUppercase,
               let previous = current.last,
               previous.isLowercase || previous.isNumber {
                components.append(current)
                current = String(character)
            } else {
                current.append(character)
            }
        }
        if !current.isEmpty {
            components.append(current)
        }

        let identifier = components
            .map { $0.lowercased() }
            .joined(separator: "-")

        let fallback = identifier.isEmpty ? defaultName : identifier
        guard let first = fallback.first, first.isLetter else {
            return "\(defaultName)-\(fallback)"
        }
        return fallback
    }

    var jsonEscaped: String {
        replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "\"", with: "\\\"")
            .replacingOccurrences(of: "\n", with: "\\n")
            .replacingOccurrences(of: "\r", with: "\\r")
            .replacingOccurrences(of: "\t", with: "\\t")
    }
}
