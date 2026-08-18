import Distributed
import Foundation
import HTTPTypes
import Logging
import SwiftHTML
import SwiftWeb
import SwiftWebHTTPServerHost
import Synchronization
import Testing

#if SWIFTWEB_ACTORS
import ActorSystemCore
import ActorSystemDistributed
#endif
@testable import SwiftWebActors
@_spi(Hosting) @testable import SwiftWebCore

@Suite
struct SwiftWebActorGroupTests {
    #if SWIFTWEB_ACTORS
    @Test
    func concreteActorGroupRegistersGeneratedBootstrapBeforeSystemStart() async throws {
        let system = try WebActorSystem(
            configuration: ActorSystemConfiguration(
                sessionIdentitySource: FixedActorSessionIdentitySource(
                    ActorSessionID(91)
                )
            )
        )
        let renderedApp = try await AppRenderer.render(
            ConcreteActorGroupBootstrapFixtureApp(system: system),
            in: AppRenderingContext()
        )

        do {
            try system.distributedBackend.registerGeneratedBootstrap(
                ConcreteActorGroupBootstrapFixture.self
            )
        } catch {
            try await renderedApp.shutdown()
            throw error
        }
        try await renderedApp.shutdown()
    }

    @Test
    func customIdentitySourceRemainsFallbackDuringVirtualActivation() async throws {
        let identitySource = SwiftWebActorGroupIdentitySource()
        let host = SwiftWebActorHost(authorization: .allowAll)
        let system = try WebActorSystem(
            identitySource: identitySource,
            actorHost: host,
            configuration: ActorSystemConfiguration(
                sessionIdentitySource: FixedActorSessionIdentitySource(
                    ActorSessionID(94)
                )
            )
        )
        let renderedApp = try await AppRenderer.render(
            ConcreteActorGroupBootstrapFixtureApp(system: system),
            in: AppRenderingContext()
        )

        do {
            let ordinary = ConcreteActorGroupBootstrapFixtureActor(
                actorSystem: system
            )
            #expect(ordinary.id.identity == "custom-1")

            let requestedAddress = ActorAddress(
                type: ConcreteActorGroupBootstrapFixture.descriptor.id,
                identity: "requested-virtual-identity"
            )
            _ = try await system.configuration.inboundInterceptor.intercept(
                ActorInvocation(
                    recipient: requestedAddress,
                    method: ActorMethodID(925),
                    schemaFingerprint: ConcreteActorGroupBootstrapFixture
                        .descriptor.schemaFingerprint,
                    payload: ActorByteBuffer()
                ),
                context: ActorInvocationContext(
                    callID: ActorCallID(
                        session: ActorSessionID(94),
                        sequence: 1
                    ),
                    origin: .local,
                    remainingTimeout: nil
                ),
                execution: ActorInvocationExecution {
                    guard let local = try system.resolve(
                        id: requestedAddress,
                        as: ConcreteActorGroupBootstrapFixtureActor.self
                    ) else {
                        throw ActorSystemError.actorNotFound(requestedAddress)
                    }
                    guard local.id == requestedAddress else {
                        throw ActorSystemError.activationFailed
                    }
                    return ActorInvocationResult()
                }
            )
            #expect(identitySource.count == 1)
        } catch {
            try await renderedApp.shutdown()
            throw error
        }
        try await renderedApp.shutdown()
    }

    @Test
    func configuredActorHostIsTheHostOwnedByTheSystem() async throws {
        let host = SwiftWebActorHost(authorization: .allowAll)
        let system = try WebActorSystem(
            configuration: ActorSystemConfiguration(
                sessionIdentitySource: FixedActorSessionIdentitySource(
                    ActorSessionID(92)
                ),
                inboundInterceptor: host
            )
        )

        #expect(system.actorHost === host)

        let termination = await host.requestShutdown()
        try await termination.wait()
    }

    @Test
    func matchingConfiguredAndExplicitActorHostIsOwnedOnce() async throws {
        let host = SwiftWebActorHost(authorization: .allowAll)
        let system = try WebActorSystem(
            actorHost: host,
            configuration: ActorSystemConfiguration(
                sessionIdentitySource: FixedActorSessionIdentitySource(
                    ActorSessionID(98)
                ),
                inboundInterceptor: host
            )
        )

        #expect(system.actorHost === host)
        #expect(system.configuration.inboundInterceptor as? SwiftWebActorHost === host)

        let termination = await host.requestShutdown()
        try await termination.wait()
    }

    @Test
    func configuredInterceptorIsComposedWithActorHostPolicy() async throws {
        let probe = SwiftWebConfiguredInterceptorProbe()
        let host = SwiftWebActorHost(authorization: .allowAll)
        let address = ActorAddress(
            type: ActorTypeID(high: 920, low: 921),
            identity: "composed-interceptor"
        )
        try await host.registerBound(address: address)
        let system = try WebActorSystem(
            actorHost: host,
            configuration: ActorSystemConfiguration(
                sessionIdentitySource: FixedActorSessionIdentitySource(
                    ActorSessionID(93)
                ),
                inboundInterceptor: SwiftWebConfiguredInterceptor(probe: probe)
            )
        )
        let invocation = ActorInvocation(
            recipient: address,
            method: ActorMethodID(922),
            schemaFingerprint: ActorSchemaFingerprint(high: 923, low: 924),
            payload: ActorByteBuffer()
        )

        let result = try await system.configuration.inboundInterceptor.intercept(
            invocation,
            context: ActorInvocationContext(
                callID: ActorCallID(session: ActorSessionID(93), sequence: 1),
                origin: .local,
                remainingTimeout: nil
            ),
            execution: ActorInvocationExecution {
                ActorInvocationResult(payload: ActorByteBuffer([1]))
            }
        )

        #expect(probe.count == 1)
        #expect(result.payload == ActorByteBuffer([1]))
        let termination = await host.requestShutdown()
        try await termination.wait()
    }

    @Test
    func configuredInterceptorIsComposedWithDefaultActorHost() async throws {
        let probe = SwiftWebConfiguredInterceptorProbe()
        let address = ActorAddress(
            type: ActorTypeID(high: 926, low: 927),
            identity: "default-host-composition"
        )
        let system = try WebActorSystem(
            configuration: ActorSystemConfiguration(
                sessionIdentitySource: FixedActorSessionIdentitySource(
                    ActorSessionID(99)
                ),
                inboundInterceptor: SwiftWebConfiguredInterceptor(probe: probe)
            )
        )
        try await system.actorHost.registerBound(address: address)

        let result = try await system.configuration.inboundInterceptor.intercept(
            ActorInvocation(
                recipient: address,
                method: ActorMethodID(928),
                schemaFingerprint: ActorSchemaFingerprint(high: 929, low: 930),
                payload: ActorByteBuffer()
            ),
            context: ActorInvocationContext(
                callID: ActorCallID(session: ActorSessionID(99), sequence: 1),
                origin: .local,
                remainingTimeout: nil
            ),
            execution: ActorInvocationExecution {
                ActorInvocationResult(payload: ActorByteBuffer([2]))
            }
        )

        #expect(probe.count == 1)
        #expect(result.payload == ActorByteBuffer([2]))
        let termination = await system.actorHost.requestShutdown()
        try await termination.wait()
    }

    @Test
    func distinctConfiguredAndExplicitActorHostsAreRejected() {
        let configuredHost = SwiftWebActorHost(authorization: .allowAll)
        let explicitHost = SwiftWebActorHost(authorization: .allowAll)

        #expect(throws: SwiftWebActorSystemConfigurationError.conflictingActorHosts) {
            _ = try WebActorSystem(
                actorHost: explicitHost,
                configuration: ActorSystemConfiguration(
                    sessionIdentitySource: FixedActorSessionIdentitySource(
                        ActorSessionID(95)
                    ),
                    inboundInterceptor: configuredHost
                )
            )
        }
    }

    @Test
    func configuredLocalInvocationClaimantIsRejectedAsASecondOwner() {
        #expect(
            throws: SwiftWebActorSystemConfigurationError.conflictingLocalInvocationOwners
        ) {
            _ = try WebActorSystem(
                configuration: ActorSystemConfiguration(
                    sessionIdentitySource: FixedActorSessionIdentitySource(
                        ActorSessionID(100)
                    ),
                    inboundInterceptor: SwiftWebConfiguredLocalClaimant()
                )
            )
        }
    }

    @Test
    func hostingCapabilitySubmitsWithoutExposingTransportLifecycle() async throws {
        let configuration = ActorSystemConfiguration(
            sessionIdentitySource: FixedActorSessionIdentitySource(
                ActorSessionID(96)
            )
        )
        let transport = try SwiftWebRequestReplyActorTransport()
        let system = try WebActorSystem(
            transports: [.swiftWebHTTP: transport],
            configuration: configuration
        )
        try await system.start()

        let response = try await system.hostingTransportCapability.submit(
            .cancellation(
                ActorCallID(session: ActorSessionID(96), sequence: 1)
            ),
            metadata: ActorByteBuffer(),
            peerIdentity: ActorByteBuffer([1]),
            authorizationIdentity: nil
        )

        #expect(response == nil)
        let termination = await system.requestShutdown()
        try await termination.wait()
    }

    @Test
    func hostingCapabilityDispatchesThroughAbstractTransportCapabilities() async throws {
        let probe = AbstractHostingCapabilityProbe()
        let transport = AbstractHostingCapabilityTransport(probe: probe)
        let capability = SwiftWebActorHostingTransportCapability(
            transports: [
                .swiftWebHTTP: transport,
                .swiftWebWebSocket: transport,
            ]
        )
        let frame = ActorFrame.cancellation(
            ActorCallID(session: ActorSessionID(97), sequence: 1)
        )
        let requestMetadata = ActorByteBuffer([2])
        let channelMetadata = ActorByteBuffer([3])
        let channel = AbstractHostingCapabilityChannel(
            endpoint: ActorEndpoint("abstract-capability")
        )

        let response = try await capability.submit(
            frame,
            metadata: requestMetadata,
            peerIdentity: ActorByteBuffer([1]),
            authorizationIdentity: nil
        )
        try await capability.attach(channel, metadata: channelMetadata)

        #expect(response == frame)
        #expect(probe.submittedFrame == frame)
        #expect(probe.submittedMetadata == requestMetadata)
        #expect(probe.attachedEndpoint == channel.endpoint)
        #expect(probe.attachedMetadata == channelMetadata)
    }
    #endif

    #if SWIFTWEB_LEGACY_ACTORS
    @Test
    func activatesVirtualActorOnDemandAndReusesInstance() async throws {
        let system = LegacyWebActorSystem()
        system.registerActivator(for: ActorGroupCounter.self) {
            _ = ActorGroupCounter(actorSystem: system)
        }
        let id = LegacyWebActorSystem.actorID(for: ActorGroupCounter.self, named: "unit-1")
        let envelope = try await capturedEnvelope(id: id, incrementBy: 3)

        let first = try await system.invoke(envelope: envelope)
        let second = try await system.invoke(envelope: envelope)

        #expect(try decodedValue(first) == 3)
        #expect(try decodedValue(second) == 6)
    }

    @Test
    func distinctNamesActivateDistinctInstances() async throws {
        let system = LegacyWebActorSystem()
        system.registerActivator(for: ActorGroupCounter.self) {
            _ = ActorGroupCounter(actorSystem: system)
        }
        let first = try await system.invoke(
            envelope: capturedEnvelope(
                id: LegacyWebActorSystem.actorID(for: ActorGroupCounter.self, named: "a"),
                incrementBy: 3
            )
        )
        let second = try await system.invoke(
            envelope: capturedEnvelope(
                id: LegacyWebActorSystem.actorID(for: ActorGroupCounter.self, named: "b"),
                incrementBy: 4
            )
        )

        #expect(try decodedValue(first) == 3)
        #expect(try decodedValue(second) == 4)
    }

    @Test
    func unregisteredContractStillFailsAsActorNotFound() async throws {
        let system = LegacyWebActorSystem()
        let id = LegacyWebActorSystem.actorID(for: ActorGroupCounter.self, named: "nobody")
        let envelope = try await capturedEnvelope(id: id, incrementBy: 1)

        await #expect(throws: (any Error).self) {
            _ = try await system.invoke(envelope: envelope)
        }
    }

    @Test
    func sceneLoweringRegistersActivatorAndInvocationEndpoint() async throws {
        let system = LegacyWebActorSystem()
        let renderedApp = try await AppRenderer.render(
            ActorGroupFixtureApp(system: system),
            in: AppRenderingContext()
        )

        let invokeRoute = renderedApp.routes.first { route in
            route.method == .post && route.path.map(String.init(describing:)) == ["_swiftweb", "actors", "invoke"]
        }
        #expect(invokeRoute != nil)

        let id = LegacyWebActorSystem.actorID(for: ActorGroupCounter.self, named: "scene-1")
        let response = try await system.invoke(envelope: capturedEnvelope(id: id, incrementBy: 2))
        #expect(try decodedValue(response) == 2)
    }

    @Test
    func actorGroupServesInvocationsOverTheHTTPServerHost() async throws {
        try await withHost(ActorGroupHostApp()) { client, base in
            let id = LegacyWebActorSystem.actorID(for: ActorGroupCounter.self, named: "e2e-1")
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
            let id = LegacyWebActorSystem.actorID(for: ActorGroupCounter.self, named: "locked-1")
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
        let system = LegacyWebActorSystem()
        system.registerActivator(for: ActorGroupCounter.self) {
            _ = ActorGroupCounter(actorSystem: system)
        }
        let id = LegacyWebActorSystem.actorID(for: ActorGroupCounter.self, named: "locked-1")

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
        let system = LegacyWebActorSystem()
        system.registerActivator(for: ActorGroupCounter.self) {
            _ = ActorGroupCounter(actorSystem: system)
        }
        let allowedID = LegacyWebActorSystem.actorID(for: ActorGroupCounter.self, named: "alice")
        let deniedID = LegacyWebActorSystem.actorID(for: ActorGroupCounter.self, named: "bob")

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
        let system = LegacyWebActorSystem()
        system.registerActivator(for: ActorGroupCounter.self) {
            _ = ActorGroupCounter(actorSystem: system)
        }
        let context = WebActorInvocationContext(transport: .http, principalID: "tester")
        let activation = WebActorActivationPolicy(maximumVirtualActorCount: 1, idleTimeout: nil)
        let firstID = LegacyWebActorSystem.actorID(for: ActorGroupCounter.self, named: "first")
        let secondID = LegacyWebActorSystem.actorID(for: ActorGroupCounter.self, named: "second")

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
        let system = LegacyWebActorSystem()
        _ = try await AppRenderer.render(
            ActorGroupEnvironmentFixtureApp(system: system),
            in: AppRenderingContext()
        )

        let id = LegacyWebActorSystem.actorID(for: ActorGroupGreeter.self, named: "env-1")
        let store = CapturedEnvelopeStore()
        let clientSystem = LegacyWebActorSystem(transport: CapturingWebActorTransport(store: store))
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
        let system = LegacyWebActorSystem()
        system.registerActivator(for: ActorGroupGreeter.self) {
            _ = ActorGroupGreeter(actorSystem: system)
        }
        let id = LegacyWebActorSystem.actorID(for: ActorGroupGreeter.self, named: "default-1")
        let store = CapturedEnvelopeStore()
        let clientSystem = LegacyWebActorSystem(transport: CapturingWebActorTransport(store: store))
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
        let clientSystem = LegacyWebActorSystem(transport: CapturingWebActorTransport(store: store))
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
            let host = HTTPServerHost(hostname: "127.0.0.1", port: port)
            let installation = try await host.render(
                app,
                logger: Logger(label: "swiftweb.tests.actor-group")
            )
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
                try await installation.shutdown()
                _ = await serveTask.result
                continue
            }
            do {
                try await body(client, "http://127.0.0.1:\(port)")
                serveTask.cancel()
                try await installation.shutdown()
                _ = await serveTask.result
                return
            } catch {
                serveTask.cancel()
                try await installation.shutdown()
                _ = await serveTask.result
                throw error
            }
        }
        throw ActorGroupTestError.serverNeverBecameReady
    }
    #endif
}

#if SWIFTWEB_ACTORS
private final class SwiftWebConfiguredInterceptorProbe: Sendable {
    private let state = Mutex(0)

    var count: Int {
        state.withLock { $0 }
    }

    func record() {
        state.withLock { $0 += 1 }
    }
}

private struct SwiftWebConfiguredInterceptor: ActorInboundInvocationInterceptor {
    let probe: SwiftWebConfiguredInterceptorProbe

    func intercept(
        _ invocation: ActorInvocation,
        context: ActorInvocationContext,
        execution: ActorInvocationExecution
    ) async throws -> ActorInvocationResult {
        _ = invocation
        _ = context
        probe.record()
        return try await execution()
    }
}

private struct SwiftWebConfiguredLocalClaimant: ActorLocalInvocationClaiming {
    func claimsLocalInvocation(for recipient: ActorAddress) async -> Bool {
        _ = recipient
        return true
    }

    func intercept(
        _ invocation: ActorInvocation,
        context: ActorInvocationContext,
        execution: ActorInvocationExecution
    ) async throws -> ActorInvocationResult {
        _ = invocation
        _ = context
        return try await execution()
    }
}

private final class SwiftWebActorGroupIdentitySource:
    ActorIdentitySource,
    Sendable
{
    private let sequence = Mutex(0)

    var count: Int {
        sequence.withLock { $0 }
    }

    func nextIdentity(for actorType: ActorTypeID) -> String {
        _ = actorType
        return sequence.withLock { sequence in
            sequence += 1
            return "custom-\(sequence)"
        }
    }
}

private final class AbstractHostingCapabilityProbe: Sendable {
    private struct State: Sendable {
        var submittedFrame: ActorFrame?
        var submittedMetadata: ActorByteBuffer?
        var attachedEndpoint: ActorEndpoint?
        var attachedMetadata: ActorByteBuffer?
    }

    private let state = Mutex(
        State(
            submittedFrame: nil,
            submittedMetadata: nil,
            attachedEndpoint: nil,
            attachedMetadata: nil
        )
    )

    var submittedFrame: ActorFrame? {
        state.withLock { $0.submittedFrame }
    }

    var submittedMetadata: ActorByteBuffer? {
        state.withLock { $0.submittedMetadata }
    }

    var attachedEndpoint: ActorEndpoint? {
        state.withLock { $0.attachedEndpoint }
    }

    var attachedMetadata: ActorByteBuffer? {
        state.withLock { $0.attachedMetadata }
    }

    func recordSubmission(frame: ActorFrame, metadata: ActorByteBuffer) {
        state.withLock { state in
            state.submittedFrame = frame
            state.submittedMetadata = metadata
        }
    }

    func recordAttachment(endpoint: ActorEndpoint, metadata: ActorByteBuffer) {
        state.withLock { state in
            state.attachedEndpoint = endpoint
            state.attachedMetadata = metadata
        }
    }
}

private struct AbstractHostingCapabilityTransport:
    ActorTransport,
    SwiftWebActorRequestSubmitting,
    SwiftWebActorChannelAttaching
{
    let incoming: AsyncThrowingStream<ActorInboundFrame, any Error>
    let probe: AbstractHostingCapabilityProbe

    init(probe: AbstractHostingCapabilityProbe) {
        self.probe = probe
        let pair = AsyncThrowingStream<ActorInboundFrame, any Error>.makeStream()
        self.incoming = pair.stream
        pair.continuation.finish()
    }

    func start() async throws {}

    func send(_ frame: ActorFrame, to endpoint: ActorEndpoint) async throws {
        _ = frame
        _ = endpoint
    }

    func shutdown() async {}

    func submit(
        _ frame: ActorFrame,
        metadata: ActorByteBuffer,
        peerIdentity: ActorByteBuffer,
        authorizationIdentity: ActorByteBuffer?
    ) async throws -> ActorFrame? {
        _ = peerIdentity
        _ = authorizationIdentity
        probe.recordSubmission(frame: frame, metadata: metadata)
        return frame
    }

    func attach(
        _ channel: any SwiftWebActorBinaryChannel,
        metadata: ActorByteBuffer
    ) async throws {
        probe.recordAttachment(endpoint: channel.endpoint, metadata: metadata)
    }
}

private struct AbstractHostingCapabilityChannel: SwiftWebActorBinaryChannel {
    let endpoint: ActorEndpoint
    let incoming: AsyncThrowingStream<ActorByteBuffer, any Error>

    init(endpoint: ActorEndpoint) {
        self.endpoint = endpoint
        let pair = AsyncThrowingStream<ActorByteBuffer, any Error>.makeStream()
        self.incoming = pair.stream
        pair.continuation.finish()
    }

    func start() async throws {}

    func send(_ bytes: ActorByteBuffer) async throws {
        _ = bytes
    }

    func shutdown() async {}
}
#endif

private enum ActorGroupTestError: Error {
    case invocationFailed
    case serverNeverBecameReady
}

// MARK: - Fixtures

#if SWIFTWEB_ACTORS
private distributed actor ConcreteActorGroupBootstrapFixtureActor {
    typealias ActorSystem = WebActorSystem
}

extension ConcreteActorGroupBootstrapFixtureActor: ActorSystemReference {
    nonisolated static var actorTypeDescriptor: ActorTypeDescriptor {
        ConcreteActorGroupBootstrapFixture.descriptor
    }
}

extension ConcreteActorGroupBootstrapFixtureActor: SwiftActorSystemBootstrapProvider {
    nonisolated static var actorSystemBootstrap: any SwiftActorSystemBootstrap.Type {
        ConcreteActorGroupBootstrapFixture.self
    }
}

private enum ConcreteActorGroupBootstrapFixture: SwiftActorSystemBootstrap {
    static let descriptor = ActorTypeDescriptor(
        id: ActorTypeID(high: 91, low: 1),
        schemaFingerprint: ActorSchemaFingerprint(high: 91, low: 2),
        methods: []
    )
    static let bootstrapIdentifier = "swiftweb-tests:concrete-actor-group"
    static let actorTypeDescriptors = [descriptor]

    static func register(in actorSystem: SwiftActorSystem) throws {
        try actorSystem.register(
            DistributedActorTypeRegistration(
                ConcreteActorGroupBootstrapFixtureActor.self,
                descriptor: descriptor,
                aliases: ActorTargetAliasTable(
                    toolchainFingerprint: "fixture",
                    aliases: [:]
                )
            ).eraseToAnyRegistration()
        )
    }
}

private struct ConcreteActorGroupBootstrapFixtureApp: App {
    let system: WebActorSystem

    init() {
        self.system = .shared
    }

    init(system: WebActorSystem) {
        self.system = system
    }

    var actorSystem: WebActorSystem {
        system
    }

    var body: some Scene {
        ActorGroup {
            ConcreteActorGroupBootstrapFixtureActor(actorSystem: $0)
        }
    }
}
#endif

#if SWIFTWEB_LEGACY_ACTORS
@Resolvable
protocol ActorGroupCounterProtocol: DistributedActor
where ActorSystem == LegacyWebActorSystem {
    distributed func increment(by amount: Int) async throws -> Int
}

@ResolvableActor(ActorGroupCounterProtocol.self)
private distributed actor ActorGroupCounter: ActorGroupCounterProtocol {
    typealias ActorSystem = LegacyWebActorSystem

    private var value = 0

    distributed func increment(by amount: Int) async throws -> Int {
        value += amount
        return value
    }
}

private struct ActorGroupFixtureApp: App {
    let system: LegacyWebActorSystem

    init() {
        self.system = .shared
    }

    init(system: LegacyWebActorSystem) {
        self.system = system
    }

    var legacyActorSystem: LegacyWebActorSystem {
        system
    }

    var body: some Scene {
        LegacyActorGroup {
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
where ActorSystem == LegacyWebActorSystem {
    distributed func greeting() async throws -> String
    distributed func greetingCapturedAtActivation() async throws -> String
}

@ResolvableActor(ActorGroupGreeterProtocol.self)
private distributed actor ActorGroupGreeter: ActorGroupGreeterProtocol {
    typealias ActorSystem = LegacyWebActorSystem

    @Environment(\.actorGreeting) private var environmentGreeting
    private let activationGreeting: String

    init(actorSystem: LegacyWebActorSystem) {
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

private struct ActorGroupEnvironmentFixtureApp: App {
    let system: LegacyWebActorSystem

    init() {
        self.system = .shared
    }

    init(system: LegacyWebActorSystem) {
        self.system = system
    }

    var legacyActorSystem: LegacyWebActorSystem {
        system
    }

    var body: some Scene {
        LegacyActorGroup {
            ActorGroupGreeter(actorSystem: system)
        }
        .environment(\.actorGreeting, "injected")
    }
}

private struct ActorGroupHostApp: App {
    static let system = LegacyWebActorSystem()

    var legacyActorSystem: LegacyWebActorSystem {
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

        LegacyActorGroup {
            ActorGroupCounter(actorSystem: legacyActorSystem)
        }
    }
}

private struct LockedActorGroupHostApp: App {
    static let system = LegacyWebActorSystem()

    var legacyActorSystem: LegacyWebActorSystem {
        Self.system
    }

    var security: SecurityConfiguration {
        var configuration = SecurityConfiguration.defaults
        configuration.csrf = .disabled
        return configuration
    }

    var body: some Scene {
        ActorGroupRootPage()

        LegacyActorGroup {
            ActorGroupCounter(actorSystem: legacyActorSystem)
        }
    }
}

@Page("/")
private struct ActorGroupRootPage {
    var document: some HTMLDocument {
        PageDocument(title: "Actor Group Host") {
            main {
                h1 { "Actor Group Host" }
            }
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
#endif
