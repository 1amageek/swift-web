import Foundation

extension TemplateProject {
    var roadmapFiles: [TemplateFile] {
        [
            TemplateFile(path: "Package.swift", contents: roadmapPackageSwift),
            TemplateFile(path: "README.md", contents: roadmapReadme),
            TemplateFile(path: "Sources/\(appName)/App.swift", contents: roadmapAppSwift),
            TemplateFile(path: "Sources/\(appName)/ClientCounter.swift", contents: roadmapClientCounterSwift),
            TemplateFile(path: "Sources/\(appName)/Routes/HomePage.swift", contents: roadmapHomePageSwift),
            TemplateFile(path: "Sources/\(appName)/Routes/CounterPage.swift", contents: roadmapCounterPageSwift),
            TemplateFile(path: "Sources/\(appName)/Routes/TokenStream.swift", contents: roadmapTokenStreamSwift),
            TemplateFile(path: "Sources/\(appName)/Routes/DocumentUpload.swift", contents: roadmapDocumentUploadSwift),
            TemplateFile(path: "Sources/\(appName)/Routes/EchoSocket.swift", contents: roadmapEchoSocketSwift),
            TemplateFile(path: "Sources/\(appName)/Routes/StreamingDemo.swift", contents: roadmapStreamingDemoSwift),
            TemplateFile(path: "Sources/\(appName)/Actions/ReserveInput.swift", contents: roadmapReserveInputSwift),
            TemplateFile(path: "Sources/\(appName)/Actions/SearchInput.swift", contents: roadmapSearchInputSwift),
            TemplateFile(path: "Sources/\(appName)/Actions/ReservationService.swift", contents: roadmapReservationServiceSwift),
            TemplateFile(path: "Sources/\(appName)/Actions/SearchService.swift", contents: roadmapSearchServiceSwift),
            TemplateFile(path: "Sources/\(appName)/Actions/CounterService.swift", contents: roadmapCounterServiceSwift),
        ]
    }

    private var roadmapPackageSwift: String {
        """
        // swift-tools-version: 6.4

        import PackageDescription

        let package = Package(
            name: "\(appName)",
            platforms: [
                .macOS("26.2"),
            ],
            products: [
                .library(name: "\(appName)", targets: ["\(appName)"]),
            ],
            dependencies: [
                .package(path: "\(FileManager.default.currentDirectoryPath)"),
                .package(url: "https://github.com/1amageek/swift-html.git", from: "0.1.0"),
            ],
            targets: [
                .target(
                    name: "\(appName)",
                    dependencies: [
                        .product(name: "SwiftHTML", package: "swift-html"),
                        .product(name: "SwiftWeb", package: "swift-web"),
                        .product(name: "SwiftWebUI", package: "swift-web"),
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

    private var roadmapReadme: String {
        """
        # \(appName)

        SwiftWeb roadmap verification app.

        Run from Terminal:

        ```bash
        swift-web build --wasm --swift-sdk swift-6.3.1-RELEASE_wasm -c release
        swift-web dev
        ```

        Verify:

        ```bash
        curl -i http://127.0.0.1:3000/
        curl -i http://127.0.0.1:3000/counter
        curl -i -X POST -H 'Content-Type: application/x-www-form-urlencoded' -d '__swiftweb_actor_id=\(appName).ReservationService&__swiftweb_action=reserve&email=hello@example.com&tickets=2' http://127.0.0.1:3000/_swiftweb/actions/\(appName).ReservationService/reserve
        curl -N http://127.0.0.1:3000/stream?message=SwiftWeb%20SSE%20works
        curl -F 'instruction=inspect' -F 'document=@README.md' http://127.0.0.1:3000/upload
        curl -N http://127.0.0.1:3000/streaming
        ```
        """
    }

    private var roadmapAppSwift: String {
        """
        import SwiftWeb

        public struct \(appName): SwiftWeb.App {
            public init() {}

            public var body: some AppContent {
                HomePage()
                CounterPage()

                SSEEndpoint(TokenStream.self, path: "/stream")
                UploadEndpoint(DocumentUpload.self, path: "/upload")
                WebSocketEndpoint(EchoSocket.self, path: "/socket")
                StreamingPageEndpoint(StreamingDemo.self, path: "/streaming")
            }
        }
        """
    }

    private var roadmapHomePageSwift: String {
        """
        import SwiftHTML
        import SwiftWeb
        import SwiftWebUI

        @Page("/")
        struct HomePage {
            private let reservationService = ReservationService(actorSystem: .shared)
            private let searchService = SearchService(actorSystem: .shared)

            var title: String {
                get async {
                    "SwiftWeb Roadmap"
                }
            }

            var description: String? {
                get async {
                    "Roadmap verification page for SwiftWeb SSR, actions, SSE, upload, WebSocket, and streaming routes."
                }
            }

            func body() -> some HTML {
                Group {
                    style { rawHTML(pageStyle) }
                    main(.class("roadmap-shell")) {
                        VStack(alignment: .stretch, spacing: .large) {
                            header(.class("roadmap-header")) {
                                VStack(alignment: .leading, spacing: .small) {
                                    Badge("SwiftWeb")
                                    h1 { "Roadmap Verification" }
                                    TextBlock("SSR, Route Actions, Server Actions, SSE, multipart upload, WebSocket, and Streaming SSR are registered as Vapor routes.", tone: .muted)
                                    p(.class("verification-note")) {
                                        "Use each control below. The response appears inside the result frame in the same card."
                                    }
                                }
                            }

                            div(.class("roadmap-grid")) {
                                panel("Counter Page") {
                                    p { "Client and server counters are available on a dedicated @Page route." }
                                    a(.href("/counter")) { "Open counter page" }
                                }

                                panel("SSR Page") {
                                    p { "This page is rendered on the server by @Page and SwiftHTML." }
                                    a(.href("/streaming"), .target("streaming-result")) { "Open streaming SSR" }
                                    resultFrame("streaming-result", label: "Streaming SSR result")
                                }

                                panel("Server Action") {
                                    form(.action(reservationService.reserveAction), .method(.post), .target("server-action-result")) {
                                        ActionMetadataFields(reservationService.reserveAction)
                                        label(.`for`("reserve-email")) { "Email" }
                                        input(.type(InputType.email), .name("email"), .value("hello@example.com"))
                                            .id("reserve-email")
                                        label(.`for`("reserve-tickets")) { "Tickets" }
                                        input(.type(InputType.number), .name("tickets"), .value("2"))
                                            .id("reserve-tickets")
                                        button(.type(ButtonType.submit)) { "Submit Server Action" }
                                    }
                                    resultFrame("server-action-result", label: "Server Action result")
                                }

                                panel("Server Action Search") {
                                    form(.action(searchService.searchAction), .method(.post), .target("search-action-result")) {
                                        ActionMetadataFields(searchService.searchAction)
                                        label(.`for`("client-search")) { "Search" }
                                        input(
                                            .type(InputType.search),
                                            .name("query"),
                                            .value("Swift"),
                                            .placeholder("Type to fetch from the action gateway")
                                        )
                                        .id("client-search")
                                        button(.type(ButtonType.submit)) { "Submit Search" }
                                    }
                                    resultFrame("search-action-result", label: "Search Action result")
                                }

                                panel("SSE") {
                                    p { "Token stream route is mounted at /stream." }
                                    a(.href("/stream?message=SwiftWeb%20SSE%20works"), .target("sse-result")) { "Open SSE stream" }
                                    resultFrame("sse-result", label: "SSE stream result")
                                }

                                panel("Multipart Upload") {
                                    form(.action("/upload"), .method(.post), .enctype("multipart/form-data"), .target("upload-result")) {
                                        label(.`for`("upload-instruction")) { "Instruction" }
                                        input(.type(InputType.text), .name("instruction"), .value("inspect"))
                                            .id("upload-instruction")
                                        label(.`for`("upload-document")) { "Document" }
                                        input(.type(InputType.file), .name("document"))
                                            .id("upload-document")
                                        button(.type(ButtonType.submit)) { "Upload" }
                                    }
                                    resultFrame("upload-result", label: "Upload result")
                                }

                                panel("WebSocket") {
                                    p { "Echo route is mounted at /socket. A normal button cannot verify the upgrade path; use a WebSocket client." }
                                }
                            }
                        }
                    }
                }
                .environment(\\.theme, .system)
            }

            private func panel(_ title: String, @HTMLBuilder _ content: () -> some HTML) -> some HTML {
                Card {
                    VStack(alignment: .stretch, spacing: .medium) {
                        h2 { title }
                        content()
                    }
                }
            }

            private func resultFrame(_ name: String, label: String) -> some HTML {
                iframe(
                    .name(name),
                    .title(label),
                    .class("result-frame"),
                    .srcdoc("<!doctype html><html><body><p>Waiting for \\(label).</p></body></html>")
                ) {}
            }

            private var pageStyle: String {
                \"\"\"
                body { margin: 0; }
                .roadmap-shell { max-width: 1180px; margin: 0 auto; padding: 32px 20px 64px; }
                .roadmap-header { padding: 12px 0 4px; }
                .roadmap-header h1 { margin: 0; font-size: 32px; line-height: 1.1; letter-spacing: 0; }
                .roadmap-grid { display: grid; grid-template-columns: repeat(auto-fit, minmax(280px, 1fr)); gap: 16px; align-items: start; }
                h2 { margin: 0; font-size: 18px; letter-spacing: 0; }
                form { display: grid; gap: 8px; }
                input, textarea, button { font: inherit; }
                input, textarea { min-height: 36px; border: 1px solid var(--swui-border); border-radius: 6px; padding: 6px 8px; box-sizing: border-box; color: var(--swui-text); background: var(--swui-surface-raised); }
                button { min-height: 36px; border: 1px solid var(--swui-border); border-radius: 6px; padding: 6px 12px; color: var(--swui-text); background: var(--swui-surface-raised); cursor: pointer; }
                a { color: var(--swui-accent); }
                .state-value { min-width: 36px; text-align: center; font-weight: 700; }
                .verification-note { margin: 0; color: var(--swui-muted); }
                .result { min-height: 42px; margin: 0; padding: 10px; border: 1px solid var(--swui-border); border-radius: 6px; background: var(--swui-surface-raised); overflow: auto; white-space: pre-wrap; }
                .result-frame { width: 100%; min-height: 148px; border: 1px solid var(--swui-border); border-radius: 6px; background: var(--swui-surface-raised); box-sizing: border-box; }
                \"\"\"
            }
        }
        """
    }

    private var roadmapCounterPageSwift: String {
        """
        import Distributed
        import SwiftWeb
        import SwiftWebUI

        @Page("/counter")
        struct CounterPage {
            private let counterService = CounterService(actorSystem: .shared)

            init() {}

            var title: String {
                get async {
                    "Counter"
                }
            }

            var description: String? {
                get async {
                    "Client and server counters for validating SwiftWeb state, hydration, and server action references."
                }
            }

            var cache: CachePolicy {
                .noStore
            }

            func load() async throws -> Int {
                try await counterService.currentValue()
            }

            func body(_ serverValue: Int) -> some HTML {
                VStack(spacing: .xlarge) {
                    VStack(spacing: .small) {
                        Badge("SwiftWeb")
                        Heading("Counter", level: .page)
                        Text(
                            "The left counter changes in client WASM. The right counter posts to Vapor and reloads this @Page with the server result.",
                            tone: .muted
                        )
                        .frame(maxWidth: "820px")
                    }

                    Grid {
                        ClientCounter()

                        Card(.class("server-counter")) {
                            VStack(spacing: .large) {
                                Heading("Server Counter")
                                Text(
                                    "Each button posts a delta to Vapor. The value is read from server state on the next render.",
                                    tone: .muted
                                )
                                ValueDisplay(label: "Server value", value: serverValue)
                                LazyHStack(spacing: .small) {
                                    Button("Decrement", action: counterService.decrementAction)
                                    Spacer()
                                    Button("Increment", action: counterService.incrementAction)
                                }
                            }
                        }
                        .frame(maxWidth: .infinity, alignment: .top)
                    }

                    Link("Back to roadmap", href: "/")
                }
                .frame(maxWidth: "920px")
                .padding(.horizontal, "var(--swui-page-inline-padding)")
                .padding(.vertical, .xlarge)
                .environment(\\.theme, .system)
            }
        }
        """
    }

    private var roadmapClientCounterSwift: String {
        """
        import SwiftHTML
        import SwiftWebUI

        public struct ClientCounter: ClientComponent, Sendable {
            @State private var value = 0

            public init() {}

            public var body: some HTML {
                Card(.class("client-counter")) {
                    VStack(spacing: .large) {
                        Heading("Client Counter")
                        Text(
                            "This state is owned by a ClientComponent running in WASM.",
                            tone: .muted
                        )
                        ValueDisplay(label: "Client value", value: value)
                        LazyHStack(spacing: .small) {
                            Button("Decrement") {
                                value -= 1
                            }
                            Spacer()
                            Button("Increment") {
                                value += 1
                            }
                        }
                    }
                }
                .frame(maxWidth: .infinity, alignment: .top)
            }
        }
        """
    }

    private var roadmapTokenStreamSwift: String {
        """
        import SwiftWeb

        struct TokenStream: SSERoute {
            struct SearchParams: Codable, Sendable {
                let message: String?
            }

            func events(_ context: SSEContext<SearchParams>) async throws -> AsyncThrowingStream<SSEEvent, any Error> {
                let message = context.searchParams.message ?? "SwiftWeb SSE works"
                return AsyncThrowingStream { continuation in
                    Task {
                        do {
                            for (index, token) in message.split(separator: " ").enumerated() {
                                continuation.yield(SSEEvent(event: "token", id: String(index), data: String(token)))
                                try await Task.sleep(for: .milliseconds(120))
                            }
                            continuation.yield(SSEEvent(event: "done", data: "complete"))
                            continuation.finish()
                        } catch {
                            continuation.finish(throwing: error)
                        }
                    }
                }
            }
        }
        """
    }

    private var roadmapDocumentUploadSwift: String {
        """
        import SwiftHTML
        import SwiftWeb

        struct DocumentUpload: UploadAction {
            struct Input: Codable, Sendable {
                let instruction: String?
            }

            func upload(_ context: UploadContext<NoParams, Input>) async throws -> ActionResult {
                let file = try await context.file("document")
                let instruction = context.input.instruction ?? "none"
                return .html(TupleComponent(
                    h1 { "Upload" },
                    p { "Instruction: \\(instruction)" },
                    p { "Filename: \\(file.filename)" },
                    p { "Bytes: \\(file.data.readableBytes)" },
                    a(.href("/")) { "Back" }
                ))
            }
        }
        """
    }

    private var roadmapEchoSocketSwift: String {
        """
        import SwiftWeb

        struct EchoSocket: WebSocketRoute {
            func connect(_ context: WebSocketContext) async throws {
                context.onText { text in
                    try await context.send("echo: \\(text)")
                }
                try await context.send("ready")
            }
        }
        """
    }

    private var roadmapStreamingDemoSwift: String {
        """
        import SwiftWeb

        struct StreamingDemo: StreamingPage {
            func stream(_ context: SSEContext<NoSearchParams>, writer: StreamWriter) async throws {
                try await writer.write("<!doctype html><html><head><meta charset=\\"utf-8\\"><meta name=\\"viewport\\" content=\\"width=device-width, initial-scale=1\\"><title>Streaming SSR</title></head><body><main style=\\"font-family: system-ui; max-width: 720px; margin: 40px auto;\\"><h1>Streaming SSR</h1><ul>")
                for index in 1...5 {
                    try await writer.write("<li>chunk \\(index)</li>")
                    try await Task.sleep(for: .milliseconds(120))
                }
                try await writer.write("</ul><a href=\\"/\\">Back</a></main></body></html>")
            }
        }
        """
    }

    private var roadmapReserveInputSwift: String {
        """
        struct ReserveInput: Codable, Sendable {
            let email: String
            let tickets: String
        }
        """
    }

    private var roadmapSearchInputSwift: String {
        """
        struct SearchInput: Codable, Sendable {
            let query: String?
        }
        """
    }

    private var roadmapReservationServiceSwift: String {
        """
        import Distributed
        import SwiftHTML
        import SwiftWeb

        distributed actor ReservationService {
            typealias ActorSystem = WebActorSystem

            @ServerAction
            distributed func reserve(_ input: ReserveInput, context: ActionInvocationContext) async throws -> ActionResult {
                .html(TupleComponent(
                    h1 { "Server Action" },
                    p { "Email: \\(input.email)" },
                    p { "Tickets: \\(input.tickets)" },
                    p { "Invocation: \\(context.id.uuidString)" },
                    p { "Actor: \\(context.actorID ?? "none")" },
                    a(.href("/")) { "Back" }
                ))
            }
        }
        """
    }

    private var roadmapSearchServiceSwift: String {
        """
        import Distributed
        import SwiftHTML
        import SwiftWeb

        distributed actor SearchService {
            typealias ActorSystem = WebActorSystem

            @ServerAction
            distributed func search(_ input: SearchInput, context: ActionInvocationContext) async throws -> ActionResult {
                let query = input.query ?? ""
                return .html(TupleComponent(
                    h3 { "Server Action Search" },
                    p { "Query: \\(query)" },
                    p { "Handled by: \\(context.requestPath)" },
                    p { "Actor: \\(context.actorID ?? "none")" }
                ))
            }
        }
        """
    }

    private var roadmapCounterServiceSwift: String {
        """
        import Distributed
        import SwiftWeb

        distributed actor CounterService {
            typealias ActorSystem = WebActorSystem
            private var value = 0

            distributed func currentValue() async throws -> Int {
                value
            }

            @ServerAction
            distributed func increment(_ input: NoActionInput, context: ActionInvocationContext) async throws -> ActionResult {
                value += 1
                return .invalidate(.page)
            }

            @ServerAction
            distributed func decrement(_ input: NoActionInput, context: ActionInvocationContext) async throws -> ActionResult {
                value -= 1
                return .invalidate(.page)
            }
        }
        """
    }
}
