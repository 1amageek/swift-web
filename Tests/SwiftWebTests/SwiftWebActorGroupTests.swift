import Distributed
import Foundation
import HTTPTypes
import Logging
import SwiftHTML
import SwiftWeb
import SwiftWebHTTPServerHost
import Testing

@testable import SwiftWebActors
@testable import SwiftWebCore

@Suite
struct SwiftWebActorGroupTests {
    @Test
    func activatesVirtualActorOnDemandAndReusesInstance() async throws {
        let system = WebActorSystem()
        system.registerActivator(for: ActorGroupCounter.self) {
            _ = ActorGroupCounter(actorSystem: system)
        }
        let id = WebActorSystem.actorID(for: ActorGroupCounter.self, named: "unit-1")
        let envelope = try await capturedEnvelope(id: id, incrementBy: 3)

        let first = try await system.invoke(envelope: envelope)
        let second = try await system.invoke(envelope: envelope)

        #expect(try decodedValue(first) == 3)
        #expect(try decodedValue(second) == 6)
    }

    @Test
    func distinctNamesActivateDistinctInstances() async throws {
        let system = WebActorSystem()
        system.registerActivator(for: ActorGroupCounter.self) {
            _ = ActorGroupCounter(actorSystem: system)
        }
        let first = try await system.invoke(
            envelope: capturedEnvelope(
                id: WebActorSystem.actorID(for: ActorGroupCounter.self, named: "a"),
                incrementBy: 3
            )
        )
        let second = try await system.invoke(
            envelope: capturedEnvelope(
                id: WebActorSystem.actorID(for: ActorGroupCounter.self, named: "b"),
                incrementBy: 4
            )
        )

        #expect(try decodedValue(first) == 3)
        #expect(try decodedValue(second) == 4)
    }

    @Test
    func unregisteredContractStillFailsAsActorNotFound() async throws {
        let system = WebActorSystem()
        let id = WebActorSystem.actorID(for: ActorGroupCounter.self, named: "nobody")
        let envelope = try await capturedEnvelope(id: id, incrementBy: 1)

        await #expect(throws: (any Error).self) {
            _ = try await system.invoke(envelope: envelope)
        }
    }

    @Test
    func sceneLoweringRegistersActivatorAndInvocationEndpoint() async throws {
        let application = TestWebApplication()
        let system = WebActorSystem()
        try await _SceneRenderer.make(
            ActorGroupFixtureScenes(system: system).scenes,
            in: _SceneContext(application: application, routes: application.routes, actorSystem: system)
        )

        let invokeRoute = application.collectedRoutes.first { route in
            route.method == .post && route.path.map(String.init(describing:)) == ["_swiftweb", "actors", "invoke"]
        }
        #expect(invokeRoute != nil)

        let id = WebActorSystem.actorID(for: ActorGroupCounter.self, named: "scene-1")
        let response = try await system.invoke(envelope: capturedEnvelope(id: id, incrementBy: 2))
        #expect(try decodedValue(response) == 2)
    }

    @Test
    func actorGroupServesInvocationsOverTheHTTPServerHost() async throws {
        try await withHost(ActorGroupHostApp()) { client, base in
            let id = WebActorSystem.actorID(for: ActorGroupCounter.self, named: "e2e-1")
            let envelope = try await capturedEnvelope(id: id, incrementBy: 5)

            let first = try await postEnvelope(envelope, client: client, base: base)
            let second = try await postEnvelope(envelope, client: client, base: base)

            #expect(try decodedValue(first) == 5)
            #expect(try decodedValue(second) == 10)
        }
    }

    @Test
    func actorGroupHTTPRejectsExternalActorByDefault() async throws {
        try await withHost(LockedActorGroupHostApp()) { client, base in
            let id = WebActorSystem.actorID(for: ActorGroupCounter.self, named: "locked-1")
            let envelope = try await capturedEnvelope(id: id, incrementBy: 1)
            var request = URLRequest(url: URL(string: "\(base)/_swiftweb/actors/invoke")!)
            request.httpMethod = "POST"
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            request.httpBody = try JSONEncoder().encode(envelope)

            let (data, response) = try await client.data(for: request)

            #expect((response as? HTTPURLResponse)?.statusCode == 403)
            #expect(String(decoding: data, as: UTF8.self).contains("External actor invocation is disabled"))
        }
    }

    @Test
    func boundActorsOnlyRejectsExternalVirtualActorWithoutAuthorizer() async throws {
        let system = WebActorSystem()
        system.registerActivator(for: ActorGroupCounter.self) {
            _ = ActorGroupCounter(actorSystem: system)
        }
        let id = WebActorSystem.actorID(for: ActorGroupCounter.self, named: "locked-1")

        await #expect(throws: WebActorAuthorizationError.self) {
            _ = try await system.invoke(
                envelope: capturedEnvelope(id: id, incrementBy: 1),
                context: WebActorInvocationContext(transport: .http),
                authorization: .boundActorsOnly
            )
        }
    }

    @Test
    func authenticatedPrincipalAuthorizerAllowsOnlyOwnedActorName() async throws {
        let system = WebActorSystem()
        system.registerActivator(for: ActorGroupCounter.self) {
            _ = ActorGroupCounter(actorSystem: system)
        }
        let allowedID = WebActorSystem.actorID(for: ActorGroupCounter.self, named: "alice")
        let deniedID = WebActorSystem.actorID(for: ActorGroupCounter.self, named: "bob")

        let allowed = try await system.invoke(
            envelope: capturedEnvelope(id: allowedID, incrementBy: 2),
            context: WebActorInvocationContext(transport: .http, principalID: "alice"),
            authorization: .authenticatedPrincipalMatchesActorName()
        )
        #expect(try decodedValue(allowed) == 2)

        await #expect(throws: WebActorAuthorizationError.self) {
            _ = try await system.invoke(
                envelope: capturedEnvelope(id: deniedID, incrementBy: 1),
                context: WebActorInvocationContext(transport: .http, principalID: "alice"),
                authorization: .authenticatedPrincipalMatchesActorName()
            )
        }
    }

    @Test
    func externalVirtualActorActivationEvictsLeastRecentlyUsedActor() async throws {
        let system = WebActorSystem()
        system.registerActivator(for: ActorGroupCounter.self) {
            _ = ActorGroupCounter(actorSystem: system)
        }
        let context = WebActorInvocationContext(transport: .http, principalID: "tester")
        let activation = WebActorActivationPolicy(maximumVirtualActorCount: 1, idleTimeout: nil)
        let firstID = WebActorSystem.actorID(for: ActorGroupCounter.self, named: "first")
        let secondID = WebActorSystem.actorID(for: ActorGroupCounter.self, named: "second")

        let first = try await system.invoke(
            envelope: capturedEnvelope(id: firstID, incrementBy: 1),
            context: context,
            authorization: .allowAll,
            activationPolicy: activation
        )
        let second = try await system.invoke(
            envelope: capturedEnvelope(id: secondID, incrementBy: 1),
            context: context,
            authorization: .allowAll,
            activationPolicy: activation
        )
        let firstAfterEviction = try await system.invoke(
            envelope: capturedEnvelope(id: firstID, incrementBy: 1),
            context: context,
            authorization: .allowAll,
            activationPolicy: activation
        )

        #expect(try decodedValue(first) == 1)
        #expect(try decodedValue(second) == 1)
        #expect(try decodedValue(firstAfterEviction) == 1)
    }

    @Test
    func sceneEnvironmentResolvesInsideActorGroupActors() async throws {
        let application = TestWebApplication()
        let system = WebActorSystem()
        try await _SceneRenderer.make(
            ActorGroupEnvironmentFixture(system: system).scenes,
            in: _SceneContext(application: application, routes: application.routes, actorSystem: system)
        )

        let id = WebActorSystem.actorID(for: ActorGroupGreeter.self, named: "env-1")
        let store = CapturedEnvelopeStore()
        let clientSystem = WebActorSystem(transport: CapturingWebActorTransport(store: store))
        let remote = try $ActorGroupGreeterProtocol.resolve(id: id, using: clientSystem)
        do {
            _ = try await remote.greeting()
            Issue.record("Capturing transport should throw after recording the envelope")
        } catch {}
        let greeting = try await system.invoke(envelope: store.requireEnvelope())
        guard case .success(let greetingData) = greeting.result else {
            throw ActorGroupTestError.invocationFailed
        }
        #expect(try JSONDecoder().decode(String.self, from: greetingData) == "injected")

        do {
            _ = try await remote.greetingCapturedAtActivation()
            Issue.record("Capturing transport should throw after recording the envelope")
        } catch {}
        let captured = try await system.invoke(envelope: store.requireEnvelope())
        guard case .success(let capturedData) = captured.result else {
            throw ActorGroupTestError.invocationFailed
        }
        #expect(try JSONDecoder().decode(String.self, from: capturedData) == "injected")
    }

    @Test
    func environmentDefaultsApplyWhenSceneSetsNothing() async throws {
        let system = WebActorSystem()
        system.registerActivator(for: ActorGroupGreeter.self) {
            _ = ActorGroupGreeter(actorSystem: system)
        }
        let id = WebActorSystem.actorID(for: ActorGroupGreeter.self, named: "default-1")
        let store = CapturedEnvelopeStore()
        let clientSystem = WebActorSystem(transport: CapturingWebActorTransport(store: store))
        let remote = try $ActorGroupGreeterProtocol.resolve(id: id, using: clientSystem)
        do {
            _ = try await remote.greeting()
            Issue.record("Capturing transport should throw after recording the envelope")
        } catch {}

        let response = try await system.invoke(envelope: store.requireEnvelope())
        guard case .success(let data) = response.result else {
            throw ActorGroupTestError.invocationFailed
        }
        #expect(try JSONDecoder().decode(String.self, from: data) == "default-greeting")
    }

    // MARK: - Helpers

    private func capturedEnvelope(id: String, incrementBy amount: Int) async throws -> InvocationEnvelope {
        let store = CapturedEnvelopeStore()
        let clientSystem = WebActorSystem(transport: CapturingWebActorTransport(store: store))
        let remote = try $ActorGroupCounterProtocol.resolve(id: id, using: clientSystem)
        do {
            _ = try await remote.increment(by: amount)
            Issue.record("Capturing transport should throw after recording the envelope")
        } catch {}
        return try await store.requireEnvelope()
    }

    private func decodedValue(_ response: ResponseEnvelope) throws -> Int {
        guard case .success(let data) = response.result else {
            throw ActorGroupTestError.invocationFailed
        }
        return try JSONDecoder().decode(Int.self, from: data)
    }

    private func postEnvelope(
        _ envelope: InvocationEnvelope,
        client: URLSession,
        base: String
    ) async throws -> ResponseEnvelope {
        var request = URLRequest(url: URL(string: "\(base)/_swiftweb/actors/invoke")!)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONEncoder().encode(envelope)
        let (data, response) = try await client.data(for: request)
        #expect((response as? HTTPURLResponse)?.statusCode == 200)
        return try JSONDecoder().decode(ResponseEnvelope.self, from: data)
    }

    private func withHost<Definition: App>(
        _ app: Definition,
        _ body: (URLSession, String) async throws -> Void
    ) async throws {
        for _ in 0..<5 {
            let port = Int.random(in: 20_000..<60_000)
            let runner = HTTPServerAppRunner(app, hostname: "127.0.0.1", port: port)
            let installation = try await runner.configure(logger: Logger(label: "swiftweb.tests.actor-group"))
            let serveTask = Task {
                try await installation.serve()
            }
            let configuration = URLSessionConfiguration.ephemeral
            configuration.httpShouldSetCookies = false
            configuration.httpCookieAcceptPolicy = .never
            configuration.timeoutIntervalForRequest = 15
            let client = URLSession(configuration: configuration)
            var ready = false
            for _ in 0..<100 {
                do {
                    _ = try await client.data(from: URL(string: "http://127.0.0.1:\(port)/")!)
                    ready = true
                    break
                } catch {
                    do {
                        try await Task.sleep(for: .milliseconds(50))
                    } catch {
                        break
                    }
                }
            }
            guard ready else {
                serveTask.cancel()
                installation.shutdown()
                _ = await serveTask.result
                continue
            }
            do {
                try await body(client, "http://127.0.0.1:\(port)")
                serveTask.cancel()
                installation.shutdown()
                _ = await serveTask.result
                return
            } catch {
                serveTask.cancel()
                installation.shutdown()
                _ = await serveTask.result
                throw error
            }
        }
        throw ActorGroupTestError.serverNeverBecameReady
    }
}

private enum ActorGroupTestError: Error {
    case invocationFailed
    case serverNeverBecameReady
}

// MARK: - Fixtures

@Resolvable
protocol ActorGroupCounterProtocol: DistributedActor
where ActorSystem == WebActorSystem {
    distributed func increment(by amount: Int) async throws -> Int
}

@ResolvableActor(ActorGroupCounterProtocol.self)
private distributed actor ActorGroupCounter: ActorGroupCounterProtocol {
    typealias ActorSystem = WebActorSystem

    private var value = 0

    distributed func increment(by amount: Int) async throws -> Int {
        value += amount
        return value
    }
}

private struct ActorGroupFixtureScenes {
    let system: WebActorSystem

    var scenes: some Scene {
        ActorGroup {
            ActorGroupCounter(actorSystem: system)
        }
    }
}

private struct ActorGroupGreetingKey: EnvironmentKey {
    static let defaultValue = "default-greeting"
}

extension EnvironmentValues {
    fileprivate var actorGreeting: String {
        get { self[ActorGroupGreetingKey.self] }
        set { self[ActorGroupGreetingKey.self] = newValue }
    }
}

@Resolvable
protocol ActorGroupGreeterProtocol: DistributedActor
where ActorSystem == WebActorSystem {
    distributed func greeting() async throws -> String
    distributed func greetingCapturedAtActivation() async throws -> String
}

@ResolvableActor(ActorGroupGreeterProtocol.self)
private distributed actor ActorGroupGreeter: ActorGroupGreeterProtocol {
    typealias ActorSystem = WebActorSystem

    @Environment(\.actorGreeting) private var environmentGreeting
    private let activationGreeting: String

    init(actorSystem: WebActorSystem) {
        self.actorSystem = actorSystem
        self.activationGreeting = EnvironmentContextReader.currentGreeting
    }

    distributed func greeting() async throws -> String {
        environmentGreeting
    }

    distributed func greetingCapturedAtActivation() async throws -> String {
        activationGreeting
    }
}

/// Reads the greeting from the ambient environment during activation, from
/// outside the actor so the read does not touch `self` mid-init.
private enum EnvironmentContextReader {
    static var currentGreeting: String {
        Environment(\.actorGreeting).wrappedValue
    }
}

private struct ActorGroupEnvironmentFixture {
    let system: WebActorSystem

    var scenes: some Scene {
        ActorGroup {
            ActorGroupGreeter(actorSystem: system)
        }
        .environment(\.actorGreeting, "injected")
    }
}

private struct ActorGroupHostApp: App {
    static let system = WebActorSystem()

    var actorSystem: WebActorSystem {
        Self.system
    }

    var security: SecurityConfiguration {
        var configuration = SecurityConfiguration.defaults
        configuration.csrf = .disabled
        configuration.actors = .allowAll
        return configuration
    }

    var body: some Scene {
        ActorGroupRootPage()

        ActorGroup {
            ActorGroupCounter(actorSystem: actorSystem)
        }
    }
}

private struct LockedActorGroupHostApp: App {
    static let system = WebActorSystem()

    var actorSystem: WebActorSystem {
        Self.system
    }

    var security: SecurityConfiguration {
        var configuration = SecurityConfiguration.defaults
        configuration.csrf = .disabled
        return configuration
    }

    var body: some Scene {
        ActorGroupRootPage()

        ActorGroup {
            ActorGroupCounter(actorSystem: actorSystem)
        }
    }
}

@Page("/")
private struct ActorGroupRootPage {
    func body() -> some HTML {
        main {
            h1 { "Actor Group Host" }
        }
    }
}

private struct CapturingWebActorTransport: WebActorTransport {
    let store: CapturedEnvelopeStore

    func call(_ envelope: InvocationEnvelope) async throws -> ResponseEnvelope {
        await store.store(envelope)
        throw RuntimeError.transportFailed("captured")
    }
}

private actor CapturedEnvelopeStore {
    private var envelope: InvocationEnvelope?

    func store(_ envelope: InvocationEnvelope) {
        self.envelope = envelope
    }

    func requireEnvelope() throws -> InvocationEnvelope {
        guard let envelope else {
            throw ActorGroupTestError.invocationFailed
        }
        return envelope
    }
}
