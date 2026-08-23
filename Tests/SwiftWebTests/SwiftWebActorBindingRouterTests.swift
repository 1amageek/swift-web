import ActorSystemCore
@testable import SwiftWebActors
import Testing

@Suite
struct SwiftWebActorBindingRouterTests {
    @Test
    func serviceRouteTemplateEncodesOnlyTheLogicalIdentityComponent() throws {
        let route = try SwiftWebActorRouteTemplate(
            transport: ActorTransportID("swiftweb.http"),
            endpointPrefix: "cloudflare-do://database/",
            endpointSuffix: "?region=primary"
        ).route(identity: "tenant A/cart/1")

        #expect(route.transport == ActorTransportID("swiftweb.http"))
        #expect(
            route.endpoint.transportSpecificAddress
                == "cloudflare-do://database/tenant%20A%2Fcart%2F1?region=primary"
        )
    }

    @Test
    func serviceRouteTemplateRejectsMissingIdentityAndTransport() {
        #expect(throws: SwiftWebActorServiceBindingError.emptyIdentity) {
            _ = try SwiftWebActorRouteTemplate(
                transport: ActorTransportID("swiftweb.http"),
                endpointPrefix: "cloudflare-do://database/"
            ).route(identity: "")
        }
        #expect(throws: SwiftWebActorServiceBindingError.emptyTransport) {
            _ = try SwiftWebActorRouteTemplate(
                transport: ActorTransportID(""),
                endpointPrefix: "cloudflare-do://database/"
            ).route(identity: "database")
        }
    }

    @Test
    func routesTwoActorAddressesToIndependentDestinations() async throws {
        let inventory = ActorAddress(
            type: ActorTypeID(high: 1, low: 10),
            identity: "inventory"
        )
        let database = ActorAddress(
            type: ActorTypeID(high: 2, low: 20),
            identity: "database"
        )
        let inventoryRoute = ActorRoute(
            transport: ActorTransportID("test.http"),
            endpoint: ActorEndpoint("https://inventory.example.test/actors")
        )
        let databaseRoute = ActorRoute(
            transport: ActorTransportID("test.rpc"),
            endpoint: ActorEndpoint("database-object")
        )
        let router = SwiftWebActorBindingRouter()

        try router.replaceRoutes(with: [
            SwiftWebActorRouteBindingRecord(
                actorID: inventory,
                route: inventoryRoute
            ),
            SwiftWebActorRouteBindingRecord(
                actorID: database,
                route: databaseRoute
            ),
        ])

        #expect(try await router.route(to: inventory) == inventoryRoute)
        #expect(try await router.route(to: database) == databaseRoute)
    }

    @Test
    func missingAddressFailsWithoutSelectingAnotherActorsRoute() async throws {
        let configured = ActorAddress(
            type: ActorTypeID(high: 1, low: 10),
            identity: "configured"
        )
        let missing = ActorAddress(
            type: configured.type,
            identity: "missing"
        )
        let router = SwiftWebActorBindingRouter()
        try router.replaceRoutes(with: [
            SwiftWebActorRouteBindingRecord(
                actorID: configured,
                route: ActorRoute(
                    transport: ActorTransportID("test.http"),
                    endpoint: ActorEndpoint("configured-endpoint")
                )
            ),
        ])

        await #expect(throws: ActorSystemError.self) {
            _ = try await router.route(to: missing)
        }
    }

    @Test
    func conflictingMaterializedRoutesAreRejected() throws {
        let actorID = ActorAddress(
            type: ActorTypeID(high: 7, low: 8),
            identity: "conflict"
        )
        let first = ActorRoute(
            transport: ActorTransportID("test.http"),
            endpoint: ActorEndpoint("first")
        )
        let second = ActorRoute(
            transport: ActorTransportID("test.http"),
            endpoint: ActorEndpoint("second")
        )
        let router = SwiftWebActorBindingRouter()

        #expect(
            throws: SwiftWebActorRouteBindingError.conflictingRoutes(
                actorID: actorID,
                first: first,
                second: second
            )
        ) {
            try router.replaceRoutes(with: [
                SwiftWebActorRouteBindingRecord(actorID: actorID, route: first),
                SwiftWebActorRouteBindingRecord(actorID: actorID, route: second),
            ])
        }
    }

    @Test
    func incompleteMaterializedRoutesAreRejectedBeforeRouting() throws {
        let router = SwiftWebActorBindingRouter()
        let type = ActorTypeID(high: 50, low: 60)
        let validAddress = ActorAddress(type: type, identity: "inventory")

        #expect(throws: SwiftWebActorRouteBindingError.emptyActorIdentity(actorType: type)) {
            try router.replaceRoutes(with: [
                SwiftWebActorRouteBindingRecord(
                    actorID: ActorAddress(type: type, identity: ""),
                    route: ActorRoute(
                        transport: ActorTransportID("swiftweb.http"),
                        endpoint: ActorEndpoint("https://inventory.example.test/actors")
                    )
                )
            ])
        }
        #expect(
            throws: SwiftWebActorRouteBindingError.emptyTransport(actorID: validAddress)
        ) {
            try router.replaceRoutes(with: [
                SwiftWebActorRouteBindingRecord(
                    actorID: validAddress,
                    route: ActorRoute(
                        transport: ActorTransportID(""),
                        endpoint: ActorEndpoint("https://inventory.example.test/actors")
                    )
                )
            ])
        }
        #expect(
            throws: SwiftWebActorRouteBindingError.emptyEndpoint(actorID: validAddress)
        ) {
            try router.replaceRoutes(with: [
                SwiftWebActorRouteBindingRecord(
                    actorID: validAddress,
                    route: ActorRoute(
                        transport: ActorTransportID("swiftweb.http"),
                        endpoint: ActorEndpoint("")
                    )
                )
            ])
        }
    }
}
