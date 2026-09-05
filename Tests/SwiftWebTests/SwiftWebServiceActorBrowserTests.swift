import ActorSystemCore
import ActorSystemDistributed
import Distributed
import Foundation
import Logging
import SwiftHTML
import SwiftWeb
import Synchronization
import Testing
@_spi(Hosting) @testable import SwiftWebActors
@_spi(Hosting) @testable import SwiftWebCore
@testable import SwiftWebHTTPServerHost

@Suite(.enabled(if: ProcessInfo.processInfo.environment["SWIFTWEB_BROWSER_E2E"] == "1"))
struct SwiftWebServiceActorBrowserTests {
    @Test(.timeLimit(.minutes(1)))
    func browserReachesOnlyTheAuthorizedSceneBoundServiceActor() async throws {
        let mainSystem = try Self.system(session: 301)
        let serviceSystem = try Self.system(session: 302)
        let executions = Mutex(0)
        let adapter = ServiceActorHTTPClient()
        try mainSystem.installActorRequestClient(adapter)
        let servicePort = Int.random(in: 20_000..<40_000)
        let mainPort = Int.random(in: 40_000..<60_000)
        let service = try await Self.install(
            ServiceActorBrowserApp(system: serviceSystem, hostsCounter: true) {
                executions.withLock { $0 += 1 }
            },
            port: servicePort
        )
        let main: HTTPServerAppInstallation
        do {
            main = try await Self.install(
                ServiceActorBrowserApp(system: mainSystem, hostsCounter: false),
                port: mainPort,
                bindings: [SwiftWebActorServiceBinding(
                    actorType: ServiceActorBrowserBootstrap.descriptor.id,
                    hostRoute: SwiftWebActorRouteTemplate(
                        transport: .swiftWebHTTP,
                        endpointPrefix: "http://127.0.0.1:\(servicePort)/_swiftweb/actors/frame?actor="
                    )
                )]
            )
        } catch {
            try await service.shutdown()
            throw error
        }
        let serviceTask = Task { try await service.serve() }
        let mainTask = Task { try await main.serve() }
        var failure: (any Error)?
        do {
            let address = ActorAddress(type: ServiceActorBrowserBootstrap.descriptor.id, identity: "primary")
            #expect(try mainSystem.resolve(id: address, as: BrowserServiceCounter.self) == nil)
            #expect(await mainSystem.actorHost.claimsLocalInvocation(for: address) == false)
            try await Self.waitForHost(port: servicePort)
            try await Self.waitForHost(port: mainPort)
            let requests = try ["primary", "primary", "unbound"].enumerated().map { index, identity in
                let frame = ActorFrame.invocation(ActorInvocationFrame(
                    callID: ActorCallID(session: ActorSessionID(303), sequence: UInt64(index + 1)),
                    invocation: ActorInvocation(
                        recipient: ActorAddress(type: address.type, identity: identity),
                        method: ActorMethodID(1),
                        schemaFingerprint: ServiceActorBrowserBootstrap.descriptor.schemaFingerprint,
                        payload: try ActorArgumentListCodec.encode([41.encodeActorValue()])
                    ),
                    remainingTimeoutNanoseconds: 5_000_000_000
                ))
                return [
                    "peer": index == 1 ? "denied-browser" : "allowed-browser",
                    "frame": Data(try mainSystem.frameCodec.encode(frame).bytes).base64EncodedString(),
                ]
            }
            let output = try await Self.runBrowser(
                base: "http://127.0.0.1:\(mainPort)",
                requests: requests
            )
            let responses = try JSONDecoder().decode([String].self, from: output)
            #expect(responses.count == 3)
            for (index, encoded) in responses.enumerated() {
                let bytes = try #require(Data(base64Encoded: encoded))
                guard case .result(let response) = try mainSystem.frameCodec.decode(ActorByteBuffer(Array(bytes))) else {
                    Issue.record("The browser must receive an Actor result frame")
                    continue
                }
                #expect(response.callID == ActorCallID(session: ActorSessionID(303), sequence: UInt64(index + 1)))
                switch index {
                case 0:
                    let expected = ActorInvocationOutcome.success(ActorInvocationResult(payload: try 42.encodeActorValue()))
                    #expect(response.outcome == expected)
                case 1:
                    #expect(response.outcome == .systemFailure(ActorSystemFailure(code: .unauthorized)))
                default:
                    #expect(response.outcome == .systemFailure(ActorSystemFailure(code: .activationFailed)))
                }
            }
            #expect(executions.withLock { $0 } == 1)
            #expect(adapter.requestCount.withLock { $0 } == 1)
        } catch {
            failure = error
        }
        for installation in [main, service] {
            do {
                try await installation.shutdown()
            } catch {
                if failure == nil { failure = error }
                else { Issue.record(error) }
            }
        }
        _ = await mainTask.result
        _ = await serviceTask.result
        if let failure { throw failure }
    }

    private static func system(session: UInt64) throws -> WebActorSystem {
        try WebActorSystem(
            router: SwiftWebActorBindingRouter(),
            transports: [.swiftWebHTTP: SwiftWebRequestReplyActorTransport()],
            configuration: ActorSystemConfiguration(
                sessionIdentitySource: FixedActorSessionIdentitySource(ActorSessionID(session))
            )
        )
    }

    private static func install(
        _ app: ServiceActorBrowserApp,
        port: Int,
        bindings: [SwiftWebActorServiceBinding] = []
    ) async throws -> HTTPServerAppInstallation {
        let rendered = try await AppRenderer.render(app, in: AppRenderingContext(
            serverConfiguration: ServerConfiguration(hostname: "127.0.0.1", port: port),
            actorServiceBindings: bindings
        ))
        let logger = Logger(label: "swiftweb.tests.service-browser")
        return HTTPServerAppInstallation(
            server: SwiftWebNIOHTTPServer(
                hostname: "127.0.0.1", port: port, transport: .plaintext,
                handler: SwiftWebHostHTTPHandler(
                    renderedApp: rendered, sessionStorage: InMemorySessionStorage(), logger: logger
                ),
                logger: logger
            ),
            renderedApp: rendered,
            developmentParentMonitor: nil
        )
    }

    private static func waitForHost(port: Int) async throws {
        let session = URLSession(configuration: .ephemeral)
        defer { session.invalidateAndCancel() }
        var request = URLRequest(url: URL(string: "http://127.0.0.1:\(port)/")!)
        request.timeoutInterval = 0.2
        for _ in 0..<50 {
            do {
                _ = try await session.data(for: request)
                return
            } catch {
                try await Task.sleep(for: .milliseconds(50))
            }
        }
        throw URLError(.cannotConnectToHost)
    }

    private static func runBrowser(base: String, requests: [[String: String]]) async throws -> Data {
        let script = URL(fileURLWithPath: #filePath).deletingLastPathComponent()
            .deletingLastPathComponent().appendingPathComponent("BrowserE2E/service-actor-http-e2e.mjs")
        let process = Process()
        let output = Pipe()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/env")
        process.arguments = ["node", script.path, base, String(decoding: try JSONEncoder().encode(requests), as: UTF8.self)]
        process.standardOutput = output
        let status: Int32 = try await withTaskCancellationHandler {
            try Task.checkCancellation()
            return try await withCheckedThrowingContinuation { continuation in
                process.terminationHandler = { continuation.resume(returning: $0.terminationStatus) }
                do {
                    try process.run()
                    if Task.isCancelled { process.terminate() }
                } catch { continuation.resume(throwing: error) }
            }
        } onCancel: {
            if process.isRunning { process.terminate() }
        }
        try Task.checkCancellation()
        #expect(status == 0)
        return output.fileHandleForReading.readDataToEndOfFile()
    }
}

// Internal visibility keeps the pinned compiler target spelling deterministic.
distributed actor BrowserServiceCounter {
    typealias ActorSystem = WebActorSystem
    private var value = 1
    private let didInvoke: @Sendable () -> Void

    init(actorSystem: WebActorSystem, didInvoke: @escaping @Sendable () -> Void) {
        self.actorSystem = actorSystem
        self.didInvoke = didInvoke
    }

    distributed func increment(by amount: Int) async throws -> Int {
        didInvoke()
        value += amount
        return value
    }
}

extension BrowserServiceCounter: ActorSystemReference, SwiftActorSystemBootstrapProvider {
    nonisolated static var actorTypeDescriptor: ActorTypeDescriptor { ServiceActorBrowserBootstrap.descriptor }
    nonisolated static var actorSystemBootstrap: any SwiftActorSystemBootstrap.Type { ServiceActorBrowserBootstrap.self }
}

private enum ServiceActorBrowserBootstrap: SwiftActorSystemBootstrap {
    static let descriptor = ActorTypeDescriptor(
        id: ActorTypeID(high: 301, low: 1),
        schemaFingerprint: ActorSchemaFingerprint(high: 301, low: 2),
        methods: [ActorMethodDescriptor(
            id: ActorMethodID(1), parameterTypeIDs: [integerType], resultTypeID: integerType, errorTypeID: nil
        )]
    )
    static let integerType = ActorTypeID(high: 301, low: 3)
    static let bootstrapIdentifier = "swiftweb-tests:service-browser"
    static let actorTypeDescriptors = [descriptor]

    static func register(in system: SwiftActorSystem) throws {
        try system.registerCodec(Int.self, typeID: integerType, codec: .portable())
        try system.register(DistributedActorTypeRegistration(
            BrowserServiceCounter.self,
            descriptor: descriptor,
            aliases: ActorTargetAliasTable(
                toolchainFingerprint: "swift-6.4.x-DEVELOPMENT-SNAPSHOT-2026-08-14-a",
                aliases: ["$s13SwiftWebTests21BrowserServiceCounterC9increment2byS2i_tYaKFTE": ActorMethodID(1)]
            )
        ).eraseToAnyRegistration())
    }
}

private struct ServiceActorBrowserApp: App {
    let system: WebActorSystem
    let hostsCounter: Bool
    let didInvoke: @Sendable () -> Void

    init() { self.init(system: .shared, hostsCounter: false) }
    init(system: WebActorSystem, hostsCounter: Bool, didInvoke: @escaping @Sendable () -> Void = {}) {
        self.system = system
        self.hostsCounter = hostsCounter
        self.didInvoke = didInvoke
    }
    var actorSystem: WebActorSystem { system }
    var security: SecurityConfiguration {
        var security = SecurityConfiguration.defaults
        // A test policy selector exercises rejection before the Service hop.
        security.actors.authorization = SwiftWebActorAuthorization { request in
            if request.context.peerID == "denied-browser" { throw ActorSystemError.unauthorized }
        }
        return security
    }
    var body: some Scene {
        if hostsCounter {
            ActorGroup { BrowserServiceCounter(actorSystem: $0, didInvoke: didInvoke) }
        } else {
            ServiceActorBrowserPage().actor(BrowserServiceCounter.self, identity: "primary")
        }
    }
}

@Page("/")
private struct ServiceActorBrowserPage {
    var document: some HTMLDocument {
        PageDocument(title: "Service Actor acceptance") { main { "Service Actor acceptance" } }
    }
}

private final class ServiceActorHTTPClient: SwiftWebActorRequestClient {
    let requestCount = Mutex(0)
    private let session = URLSession(configuration: .ephemeral)

    func requestActorFrame(
        _ encodedFrame: ActorByteBuffer,
        to endpoint: ActorEndpoint,
        onDispatched: @escaping @Sendable () -> Void
    ) async throws -> ActorByteBuffer? {
        let url = try #require(URL(string: endpoint.transportSpecificAddress))
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.timeoutInterval = 5
        request.httpBody = Data(encodedFrame.bytes)
        request.setValue("application/vnd.swift-actor-frame", forHTTPHeaderField: "Content-Type")
        request.setValue("http://127.0.0.1:\(url.port!)", forHTTPHeaderField: "Origin")
        request.setValue("service-adapter", forHTTPHeaderField: "X-SwiftWeb-Actor-Peer-ID")
        request.setValue("csrf_token=service-adapter-token", forHTTPHeaderField: "Cookie")
        request.setValue("service-adapter-token", forHTTPHeaderField: "X-CSRF-Token")
        requestCount.withLock { $0 += 1 }
        onDispatched()
        let (data, response) = try await session.data(for: request)
        #expect((response as? HTTPURLResponse)?.statusCode == 200)
        return ActorByteBuffer(Array(data))
    }

    func shutdown() async { session.invalidateAndCancel() }
}
