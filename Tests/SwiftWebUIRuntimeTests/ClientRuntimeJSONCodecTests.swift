import Foundation
import ActorSystemCore
import SwiftHTML
import SwiftWebActors
@testable import SwiftWebUIRuntime
import Testing

@Suite
struct ClientRuntimeJSONCodecTests {
    @Test
    func decodesServerBootstrapPayloadWithoutCodableWitnessDispatch() throws {
        let request = ClientRuntimeBootstrapRequest(
            hydrationIndex: hydrationIndex(),
            documentNodeIDUpperBound: 24,
            location: ClientRuntimeBootstrapLocation(
                href: "http://127.0.0.1:8080/counter?value=7",
                search: "?value=7"
            ),
            mode: .navigation,
            stateSnapshot: StateStoreSnapshot(
                schemaHash: "schema",
                values: [
                    "counter": StateSnapshotValue(
                        valueType: "Swift.Int",
                        encodedValue: "7"
                    ),
                ]
            ),
            actorBindings: [
                SwiftWebActorBindingRecord(
                    contractKey: "CounterService",
                    actorID: ActorAddress(
                        type: ActorTypeID(high: 1, low: 2),
                        identity: "counter-1"
                    )
                ),
            ],
            actorRouteBindings: [
                SwiftWebActorRouteBindingRecord(
                    actorID: ActorAddress(
                        type: ActorTypeID(high: 1, low: 2),
                        identity: "counter-1"
                    ),
                    route: ActorRoute(
                        transport: ActorTransportID("swiftweb.http"),
                        endpoint: ActorEndpoint("https://counter.example.test/actors")
                    )
                ),
            ]
        )

        let data = try JSONEncoder().encode(request)
        let decoded = try ClientRuntimeJSONCodec.decodeBootstrapRequest(from: data)

        #expect(decoded == request)
    }

    @Test
    func decodesBrowserEventPayload() throws {
        let data = Data(
            #"""
            {
              "handlerID": {"rawValue": "h1"},
              "event": {
                "value": "updated",
                "checked": true,
                "key": "Enter",
                "code": "Enter",
                "inputType": "insertText",
                "clientX": 12.5,
                "clientY": 24.5,
                "metadata": {"source": "browser"}
              },
              "componentID": {"rawValue": "c1"}
            }
            """#.utf8
        )

        let decoded = try ClientRuntimeJSONCodec.decodeEventRequest(from: data)

        #expect(decoded.handlerID == HandlerID("h1"))
        #expect(decoded.componentID == ComponentID("c1"))
        #expect(decoded.event.value == "updated")
        #expect(decoded.event.checked == true)
        #expect(decoded.event.key == "Enter")
        #expect(decoded.event.clientX == 12.5)
        #expect(decoded.event.metadata == ["source": "browser"])
    }

    @Test
    func encodesResponseCompatibleWithBrowserWireFormat() throws {
        let response = ClientRuntimeResponse(
            commandBatch: BrowserDOMCommandBatch(commands: [
                .updateText(node: HTMLNodeID(1), value: "updated"),
                .setProperty(node: HTMLNodeID(1), name: "value", value: nil),
                .moveKeyed(
                    parent: HTMLNodeID(1),
                    key: Key(rawValue: "row", identity: "row#duplicate:1"),
                    to: 2
                ),
            ]),
            hydrationIndex: hydrationIndex()
        )

        let data = try ClientRuntimeJSONCodec.encode(response)
        let decoded = try JSONDecoder().decode(ClientRuntimeResponse.self, from: data)

        #expect(decoded == response)
    }

    @Test
    func stateSnapshotRoundTripsThroughRuntimeCodec() throws {
        let snapshot = StateStoreSnapshot(
            schemaHash: "schema",
            values: [
                "counter": StateSnapshotValue(
                    valueType: "Swift.Int",
                    encodedValue: "8"
                ),
            ]
        )

        let data = try ClientRuntimeJSONCodec.encode(snapshot)
        let decoded = try ClientRuntimeJSONCodec.decodeStateSnapshot(from: data)

        #expect(decoded == snapshot)
    }

    @Test
    func rejectsMalformedBootstrapPayload() throws {
        let data = Data(#"{"hydrationIndex":[]}"#.utf8)

        #expect(throws: ClientRuntimeJSONCodecError.self) {
            try ClientRuntimeJSONCodec.decodeBootstrapRequest(from: data)
        }
    }

    @Test
    func rejectsJSONNumbersWhereBooleanFieldsAreRequired() throws {
        let data = Data(
            #"""
            {
              "handlerID": {"rawValue": "h1"},
              "event": {"checked": 1}
            }
            """#.utf8
        )

        #expect(throws: ClientRuntimeJSONCodecError.self) {
            try ClientRuntimeJSONCodec.decodeEventRequest(from: data)
        }
    }

    @Test
    func embeddedCodecPreservesBootstrapPayloadAndUInt64ActorType() throws {
        let request = ClientRuntimeBootstrapRequest(
            hydrationIndex: hydrationIndex(),
            documentNodeIDUpperBound: 24,
            location: ClientRuntimeBootstrapLocation(
                href: "https://example.test/counter",
                search: ""
            ),
            mode: .standard,
            actorBindings: [
                SwiftWebActorBindingRecord(
                    contractKey: "CounterService",
                    actorID: ActorAddress(
                        type: ActorTypeID(high: UInt64.max, low: UInt64.max - 1),
                        identity: "counter-embedded"
                    )
                ),
            ],
            actorRouteBindings: [
                SwiftWebActorRouteBindingRecord(
                    actorID: ActorAddress(
                        type: ActorTypeID(high: UInt64.max, low: UInt64.max - 1),
                        identity: "counter-embedded"
                    ),
                    route: ActorRoute(
                        transport: ActorTransportID("swiftweb.http"),
                        endpoint: ActorEndpoint("https://counter.example.test/actors")
                    )
                ),
            ]
        )

        let bytes = Array(try JSONEncoder().encode(request))
        let decoded = try ClientRuntimeEmbeddedJSONCodec.decodeBootstrapRequest(from: bytes)

        #expect(decoded == request)
    }

    @Test
    func embeddedCodecResponseMatchesCodableWireShape() throws {
        let response = ClientRuntimeResponse(
            commandBatch: BrowserDOMCommandBatch(commands: [
                .updateText(node: HTMLNodeID(1), value: "埋め込み\nruntime"),
                .setProperty(node: HTMLNodeID(1), name: "value", value: nil),
            ]),
            hydrationIndex: hydrationIndex(),
            atomicStyleRules: [
                ClientRuntimeAtomicStyleRule(className: "s1", body: "color: red"),
            ]
        )

        let bytes = try ClientRuntimeEmbeddedJSONCodec.encode(response)
        let decoded = try JSONDecoder().decode(ClientRuntimeResponse.self, from: Data(bytes))

        #expect(decoded == response)
    }

    @Test
    func embeddedCodecRejectsMalformedJSONWithoutTrapping() throws {
        let bytes = Array(#"{"handlerID":"h1","event":{"value":"\uD800"}}"#.utf8)

        #expect(throws: ClientRuntimeJSONCodecError.self) {
            try ClientRuntimeEmbeddedJSONCodec.decodeEventRequest(from: bytes)
        }
    }

    private func hydrationIndex() -> BrowserHydrationIndex {
        let componentID = ComponentID("c1")
        let handlerID = HandlerID("h1")
        let serverSlotID = ServerSlotID("slot-1")
        let eventBinding = BrowserHydrationEventBinding(
            nodeID: HTMLNodeID(1),
            handlerID: handlerID,
            eventName: "click",
            componentID: componentID
        )
        let stateSource = StateSourceLocation(
            fileID: "Counter.swift",
            line: 10,
            column: 5
        )
        return BrowserHydrationIndex(
            rootID: HTMLNodeID(1),
            nodes: [
                BrowserHydrationNodeRecord(
                    id: HTMLNodeID(1),
                    parentID: nil,
                    childIDs: [],
                    role: .element,
                    name: "button",
                    componentID: componentID,
                    serverSlotID: serverSlotID,
                    attributes: [
                        HTMLAttributeRecord(
                            name: "data-event-click",
                            value: "h1",
                            kind: .eventBinding,
                            handlerID: handlerID,
                            eventName: "click"
                        ),
                    ],
                    eventBindings: [eventBinding],
                    key: Key(rawValue: "button", identity: "button"),
                    fingerprint: NodeFingerprint(42)
                ),
            ],
            components: [
                BrowserHydrationComponentRecord(
                    id: componentID,
                    typeName: "Counter",
                    path: "document:body/content",
                    nodeID: HTMLNodeID(1),
                    bundleID: ClientBundleID("counter"),
                    loadPolicy: .visible,
                    serverSlotIDs: [serverSlotID],
                    stateSlots: [
                        StateSlotRecord(
                            id: StateSlotID(componentID: componentID, source: stateSource),
                            componentID: componentID,
                            valueType: "Swift.Int",
                            source: stateSource
                        ),
                    ],
                    environmentSnapshot: ClientEnvironmentSnapshot(values: [
                        ClientEnvironmentSnapshotValue(
                            key: "Locale",
                            valueType: "Swift.String",
                            encoding: "json",
                            encodedValue: "\"en\""
                        ),
                    ])
                ),
            ],
            serverSlots: [
                ServerSlotRecord(
                    id: serverSlotID,
                    ownerComponentID: componentID,
                    componentType: "Counter",
                    path: "document:body/content/server",
                    nodeID: HTMLNodeID(1)
                ),
            ],
            handlers: [eventBinding]
        )
    }
}
