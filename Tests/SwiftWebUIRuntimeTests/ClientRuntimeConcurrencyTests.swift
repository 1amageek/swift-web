import ActorSystemCore
import Foundation
import SwiftHTML
import Synchronization
@testable import SwiftWebUIRuntime
import Testing

private final class ReentrantBrowserDOMHost: BrowserDOMHost {
    private let operation = Mutex<(@Sendable () throws -> Void)?>(nil)

    func setOperation(_ operation: (@Sendable () throws -> Void)?) {
        self.operation.withLock { current in
            current = operation
        }
    }

    func apply(
        _ batch: BrowserDOMCommandBatch,
        currentIndex: BrowserHydrationIndex
    ) throws {
        let operation = operation.withLock { operation in
            operation
        }
        try operation?()
    }
}

private struct ReentrantRuntimeCounter: ClientComponent {
    @State private var count = 0

    var content: some Component {
        button(.onClick {
            count += 1
        }) {
            "\(count)"
        }
    }
}

private enum BundleTransactionFixture {
    private static let storage = Mutex("Server")
    private static let failureStorage = Mutex(false)

    static var text: String {
        get { storage.withLock { $0 } }
        set { storage.withLock { $0 = newValue } }
    }

    static var shouldFailSecond: Bool {
        get { failureStorage.withLock { $0 } }
        set { failureStorage.withLock { $0 = newValue } }
    }
}

private struct BundleTransactionFirst: ClientComponent {
    @State private var count = 0

    var content: some Component {
        button(.onClick { count += 1 }) {
            "\(BundleTransactionFixture.text):\(count)"
        }
    }
}

private struct BundleTransactionSecond: ClientComponent {
    @State private var count = 0

    var content: some Component {
        button(.onClick { count += 1 }) {
            "Second:\(count)"
        }
    }
}

private struct BundleTransactionPage: Component {
    var content: some Component {
        div {
            BundleTransactionFirst()
            BundleTransactionSecond()
        }
    }
}

private enum BundleTransactionError: Error {
    case intentionalFailure
    case encodingFailure
}

private struct NestedRuntimeInner: ClientComponent {
    @State private var count = 0

    var content: some Component {
        button(.onClick { count += 1 }) { "inner:\(count)" }
    }
}

private struct NestedRuntimeOuter: ClientComponent {
    @State private var count = 0

    var content: some Component {
        div {
            button(.onClick { count += 1 }) { "outer:\(count)" }
            NestedRuntimeInner()
        }
    }
}

private struct NestedRuntimePage: Component {
    var content: some Component {
        NestedRuntimeOuter()
    }
}

private struct RepeatedRuntimeCounter: ClientComponent {
    @State private var count = 0

    var content: some Component {
        button(.onClick { count += 1 }) { "repeated:\(count)" }
    }
}

private struct RepeatedRuntimePage: Component {
    var content: some Component {
        div {
            RepeatedRuntimeCounter()
            RepeatedRuntimeCounter()
        }
    }
}

@Suite(.serialized)
struct ClientRuntimeConcurrencyTests {
    @Test
    func actorFetchFailureNormalizationHonorsCancellationAndShutdown() {
        struct AdapterFailure: Error {}

        let cancelled = JavaScriptKitActorRequestErrorNormalizer.normalize(
            AdapterFailure(),
            isCancelled: true,
            isAccepting: true
        )
        #expect(cancelled.code == .cancelled)

        let shutdown = JavaScriptKitActorRequestErrorNormalizer.normalize(
            AdapterFailure(),
            isCancelled: false,
            isAccepting: false
        )
        #expect(shutdown.code == .transportClosed)

        let rejected = JavaScriptKitActorRequestErrorNormalizer.normalize(
            AdapterFailure(),
            isCancelled: false,
            isAccepting: true
        )
        #expect(rejected.code == .transportClosed)

        let protocolFailure = JavaScriptKitActorRequestErrorNormalizer.normalize(
            ActorSystemError.decodingFailed,
            isCancelled: false,
            isAccepting: true
        )
        #expect(protocolFailure.code == .decodingFailed)
    }

    @Test
    func bridgeShutdownIsTerminal() async throws {
        let index = RepeatedRuntimeCounter().renderArtifact().browserHydrationIndex()
        let request = ClientRuntimeBootstrapRequest(
            hydrationIndex: index,
            location: ClientRuntimeBootstrapLocation(href: "/", search: "")
        )
        let bridge = ClientRuntimeBridge<RepeatedRuntimeCounter> { _ in
            RepeatedRuntimeCounter()
        }
        _ = try bridge.bootstrap(request)
        try await bridge.shutdown()

        #expect(throws: ClientRuntimeBridgeError.self) {
            _ = try bridge.bootstrap(request)
        }
    }

    @Test
    func bundleShutdownReportsCompletionOnlyAfterItsOwnerTaskFinishes() async throws {
        let index = RepeatedRuntimePage().renderArtifact().browserHydrationIndex()
        let entrypoint = ClientBundleRuntimeEntrypoint(
            registrations: [
                ClientComponentRegistration(RepeatedRuntimeCounter.self) { _ in
                    RepeatedRuntimeCounter()
                },
            ],
            domHost: nil
        )
        _ = try entrypoint.bootstrap(
            ClientRuntimeBootstrapRequest(
                hydrationIndex: index,
                location: ClientRuntimeBootstrapLocation(href: "/", search: "")
            )
        )

        #expect(entrypoint.shutdown() == 3)
        while entrypoint.shutdownStatus() == 3 {
            await Task.yield()
        }
        #expect(entrypoint.shutdownStatus() == 0)
    }

    @Test
    func bundleNamespacesStateForRepeatedComponentTypes() throws {
        let serverIndex = RepeatedRuntimePage().renderArtifact().browserHydrationIndex()
        let serverComponents = serverIndex.components.filter {
            $0.typeName.hasSuffix("RepeatedRuntimeCounter")
        }
        #expect(serverComponents.count == 2)
        #expect(Set(serverComponents.map(\.id)).count == 2)
        #expect(Set(serverComponents.map(\.path)).count == 2)
        let entrypoint = ClientBundleRuntimeEntrypoint(
            registrations: [
                ClientComponentRegistration(RepeatedRuntimeCounter.self) { _ in
                    RepeatedRuntimeCounter()
                }
            ],
            domHost: nil
        )
        let bootstrap = try entrypoint.bootstrap(
            ClientRuntimeBootstrapRequest(
                hydrationIndex: serverIndex,
                location: ClientRuntimeBootstrapLocation(href: "/", search: ""),
                mode: .hotReload
            )
        )
        let index = try #require(bootstrap.hydrationIndex)
        let components = index.components.filter {
            $0.typeName.hasSuffix("RepeatedRuntimeCounter")
        }
        #expect(components.count == 2)
        #expect(Set(components.map(\.id)).count == 2)
        #expect(Set(components.map(\.path)).count == 2)
        var updatedTexts: [String] = []
        for component in components {
            let binding = try #require(handler(in: index, rootedAt: component.nodeID))
            #expect(binding.componentID == component.id)
            let update = try entrypoint.dispatch(
                ClientRuntimeEventRequest(
                    handlerID: binding.handlerID,
                    event: DOMEvent(),
                    componentID: component.id
                )
            )
            for command in update.commandBatch?.commands ?? [] {
                if case .updateText(_, let value) = command, value.hasPrefix("repeated:") {
                    updatedTexts.append(value)
                }
            }
        }
        #expect(updatedTexts == ["repeated:1", "repeated:1"])

        let snapshot = try entrypoint.snapshotStateValue()
        #expect(snapshot.values.count == 2)
        #expect(Set(snapshot.values.keys).count == 2)

        _ = try entrypoint.bootstrap(
            ClientRuntimeBootstrapRequest(
                hydrationIndex: index,
                location: ClientRuntimeBootstrapLocation(href: "/", search: ""),
                mode: .hotReload,
                stateSnapshot: snapshot
            )
        )
        #expect(try entrypoint.snapshotStateValue().values == snapshot.values)
    }

    @Test
    func bundleBootstrapDoesNotApplyPartialDOMWhenLaterRuntimeFails() throws {
        BundleTransactionFixture.text = "Server"
        BundleTransactionFixture.shouldFailSecond = true
        let serverIndex = BundleTransactionPage().renderArtifact().browserHydrationIndex()
        BundleTransactionFixture.text = "Client"
        defer { BundleTransactionFixture.text = "Server" }
        defer { BundleTransactionFixture.shouldFailSecond = false }
        let host = ReentrantBrowserDOMHost()
        let entrypoint = ClientBundleRuntimeEntrypoint(
            registrations: [
                ClientComponentRegistration(BundleTransactionFirst.self) { _ in
                    BundleTransactionFirst()
                },
                ClientComponentRegistration(BundleTransactionSecond.self) { _ in
                    if BundleTransactionFixture.shouldFailSecond {
                        throw BundleTransactionError.intentionalFailure
                    }
                    return BundleTransactionSecond()
                },
            ],
            domHost: host
        )
        let applyCount = Mutex(0)
        host.setOperation {
            applyCount.withLock { $0 += 1 }
        }

        #expect(throws: BundleTransactionError.self) {
            _ = try entrypoint.bootstrap(
                ClientRuntimeBootstrapRequest(
                    hydrationIndex: serverIndex,
                    location: ClientRuntimeBootstrapLocation(href: "/", search: ""),
                    mode: .hotReload
                )
            )
        }

        #expect(applyCount.withLock { $0 } == 0)
    }

    @Test
    func bundleHotReloadPreservesEveryComponentStateAndRollsBackFailure() throws {
        BundleTransactionFixture.text = "Server"
        BundleTransactionFixture.shouldFailSecond = false
        let serverIndex = BundleTransactionPage().renderArtifact().browserHydrationIndex()
        let entrypoint = ClientBundleRuntimeEntrypoint(
            registrations: [
                ClientComponentRegistration(BundleTransactionFirst.self) { _ in
                    BundleTransactionFirst()
                },
                ClientComponentRegistration(BundleTransactionSecond.self) { _ in
                    if BundleTransactionFixture.shouldFailSecond {
                        throw BundleTransactionError.intentionalFailure
                    }
                    return BundleTransactionSecond()
                },
            ],
            domHost: nil
        )
        let bootstrap = try entrypoint.bootstrap(
            ClientRuntimeBootstrapRequest(
                hydrationIndex: serverIndex,
                location: ClientRuntimeBootstrapLocation(href: "/", search: "")
            )
        )
        let index = try #require(bootstrap.hydrationIndex)
        for componentType in ["BundleTransactionFirst", "BundleTransactionSecond"] {
            let component = try #require(index.components.first { $0.typeName.hasSuffix(componentType) })
            let handler = try #require(handler(in: index, rootedAt: component.nodeID))
            _ = try entrypoint.dispatch(
                ClientRuntimeEventRequest(
                    handlerID: handler.handlerID,
                    event: DOMEvent(),
                    componentID: component.id
                )
            )
        }
        let beforeReload = try entrypoint.snapshotStateValue()
        #expect(beforeReload.values.count == 2)

        _ = try entrypoint.bootstrap(
            ClientRuntimeBootstrapRequest(
                hydrationIndex: index,
                location: ClientRuntimeBootstrapLocation(href: "/", search: ""),
                mode: .hotReload,
                stateSnapshot: beforeReload
            )
        )
        #expect(try entrypoint.snapshotStateValue().values == beforeReload.values)

        BundleTransactionFixture.shouldFailSecond = true
        defer { BundleTransactionFixture.shouldFailSecond = false }
        #expect(throws: BundleTransactionError.self) {
            _ = try entrypoint.bootstrap(
                ClientRuntimeBootstrapRequest(
                    hydrationIndex: index,
                    location: ClientRuntimeBootstrapLocation(href: "/", search: ""),
                    mode: .hotReload,
                    stateSnapshot: beforeReload
                )
            )
        }
        #expect(try entrypoint.snapshotStateValue().values == beforeReload.values)
    }

    @Test
    func nestedHandlerDispatchesToInnermostRegisteredRuntime() throws {
        let index = NestedRuntimePage().renderArtifact().browserHydrationIndex()
        let entrypoint = ClientBundleRuntimeEntrypoint(
            registrations: [
                ClientComponentRegistration(NestedRuntimeOuter.self) { _ in NestedRuntimeOuter() },
                ClientComponentRegistration(NestedRuntimeInner.self) { _ in NestedRuntimeInner() },
            ],
            domHost: nil
        )
        let response = try entrypoint.bootstrap(
            ClientRuntimeBootstrapRequest(
                hydrationIndex: index,
                location: ClientRuntimeBootstrapLocation(href: "/", search: ""),
                mode: .hotReload
            )
        )
        let hydrated = try #require(response.hydrationIndex)
        let inner = try #require(hydrated.components.first { $0.typeName.hasSuffix("NestedRuntimeInner") })
        let handler = try #require(handler(in: hydrated, rootedAt: inner.nodeID))
        let update = try entrypoint.dispatch(
            ClientRuntimeEventRequest(handlerID: handler.handlerID, event: DOMEvent())
        )
        #expect(update.commandBatch?.commands.contains { command in
            if case .updateText(_, let value) = command {
                return value == "inner:1"
            }
            return false
        } == true)
    }

    @Test
    func bundleEntrypointReportsABIStatusesAndCopiesOwnedResponse() throws {
        let index = BundleTransactionPage().renderArtifact().browserHydrationIndex()
        let request = ClientRuntimeBootstrapRequest(
            hydrationIndex: index,
            location: ClientRuntimeBootstrapLocation(href: "/", search: "")
        )
        let reentryStatus = Mutex<UInt32?>(nil)
        let entrypointBox = Mutex<ClientBundleRuntimeEntrypoint?>(nil)
        let entrypoint = ClientBundleRuntimeEntrypoint(
            registrations: [
                ClientComponentRegistration(BundleTransactionFirst.self) { _ in
                    if let current = entrypointBox.withLock({ $0 }) {
                        reentryStatus.withLock { $0 = current.snapshotState() }
                    }
                    return BundleTransactionFirst()
                },
                ClientComponentRegistration(BundleTransactionSecond.self) { _ in
                    BundleTransactionSecond()
                },
            ],
            domHost: nil
        )
        entrypointBox.withLock { $0 = entrypoint }

        #expect(entrypoint.bootstrapStatus(request) == 0)
        #expect(reentryStatus.withLock { $0 } == 2)
        let length = Int(entrypoint.responseLength())
        #expect(length > 0)
        let destination = UnsafeMutableRawPointer.allocate(byteCount: length, alignment: 1)
        defer { destination.deallocate() }
        #expect(entrypoint.copyResponse(to: destination, capacity: length) == length)
        let response = try JSONDecoder().decode(
            ClientRuntimeResponse.self,
            from: Data(bytes: destination, count: length)
        )
        #expect(response.error == nil)
        entrypoint.freeResponse()
        #expect(entrypoint.responseLength() == 0)

        let failingStorage = ClientRuntimeResponseStorage(
            responseEncoder: { _ in throw BundleTransactionError.encodingFailure }
        )
        let failingEntrypoint = ClientBundleRuntimeEntrypoint(
            registrations: [
                ClientComponentRegistration(BundleTransactionFirst.self) { _ in
                    BundleTransactionFirst()
                },
                ClientComponentRegistration(BundleTransactionSecond.self) { _ in
                    BundleTransactionSecond()
                },
            ],
            domHost: nil,
            responseStorage: failingStorage
        )
        #expect(failingEntrypoint.bootstrapStatus(request) == 1)
        #expect(failingEntrypoint.responseLength() > 0)
    }

    @Test
    func rejectsDOMCallbackReentryAndReleasesOperationOwnership() throws {
        let host = ReentrantBrowserDOMHost()
        let bridge = ClientRuntimeBridge<ReentrantRuntimeCounter>(
            domHost: host
        ) { _ in
            ReentrantRuntimeCounter()
        }
        let bootstrap = try bridge.bootstrap(
            ClientRuntimeBootstrapRequest(
                hydrationIndex: .empty,
                location: ClientRuntimeBootstrapLocation(href: "/", search: "")
            )
        )
        let handler = try #require(bootstrap.hydrationIndex?.handlers.first)
        host.setOperation {
            _ = try bridge.snapshotState()
        }

        #expect(throws: ClientRuntimeAccessError.self) {
            try bridge.dispatch(
                ClientRuntimeEventRequest(
                    handlerID: handler.handlerID,
                    event: DOMEvent()
                )
            )
        }

        host.setOperation(nil)
        let update = try bridge.dispatch(
            ClientRuntimeEventRequest(
                handlerID: handler.handlerID,
                event: DOMEvent()
            )
        )
        #expect(update.commandBatch?.commands == [
            .updateText(node: HTMLNodeID(0), value: "2"),
        ])
    }

    @Test
    func responseStorageSynchronizesConcurrentWriters() async {
        let storage = ClientRuntimeResponseStorage()

        await withTaskGroup(of: Void.self) { group in
            for value in 0..<64 {
                group.addTask {
                    storage.store(Data("\(value)".utf8))
                    _ = storage.responseLength()
                }
            }
        }

        #expect(storage.responseLength() > 0)
        storage.free()
        #expect(storage.responseLength() == 0)
    }

    @Test
    func responseStorageCopiesOneCompleteResponseWhileWritersRace() async {
        let storage = ClientRuntimeResponseStorage()
        let first = Data(repeating: 0x41, count: 4_096)
        let second = Data(repeating: 0x42, count: 4_096)
        storage.store(first)

        await withTaskGroup(of: Void.self) { group in
            for index in 0..<64 {
                group.addTask {
                    storage.store(index.isMultiple(of: 2) ? first : second)
                }
                group.addTask {
                    let destination = UnsafeMutableRawPointer.allocate(
                        byteCount: 4_096,
                        alignment: 1
                    )
                    defer { destination.deallocate() }
                    let copied = storage.copyResponse(to: destination, capacity: 4_096)
                    #expect(copied == 4_096)
                    let data = Data(bytes: destination, count: copied)
                    #expect(data == first || data == second)
                }
            }
        }
    }

    @Test
    func nodeMapSupportsLargeInsertLookupInvertAndRemoval() {
        var map = NodeMap()
        for value in 0..<20_000 {
            map[HTMLNodeID(value)] = HTMLNodeID(value + 30_000)
        }

        #expect(map.count == 20_000)
        for value in 0..<20_000 {
            #expect(map[HTMLNodeID(value)] == HTMLNodeID(value + 30_000))
        }
        let inverted = map.inverted()
        for value in 0..<20_000 {
            #expect(inverted[HTMLNodeID(value + 30_000)] == HTMLNodeID(value))
        }
        for value in stride(from: 0, to: 20_000, by: 2) {
            map[HTMLNodeID(value)] = nil
        }
        #expect(map.count == 10_000)
    }

    private func handler(
        in index: BrowserHydrationIndex,
        rootedAt rootID: HTMLNodeID
    ) -> BrowserHydrationEventBinding? {
        var pending = [rootID]
        var visited = NodeIDSet()
        while let nodeID = pending.popLast() {
            guard visited.insert(nodeID) else {
                continue
            }
            if let handler = index.handlers.first(where: { $0.nodeID == nodeID }) {
                return handler
            }
            if let node = index.node(nodeID) {
                pending.append(contentsOf: node.childIDs)
            }
        }
        return nil
    }
}
