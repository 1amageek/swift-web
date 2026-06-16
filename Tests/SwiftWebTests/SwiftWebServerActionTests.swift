import Distributed
import Foundation
import SwiftHTML
@testable import SwiftWeb
import Testing
import Vapor

@Suite
struct SwiftWebServerActionTests {
    @Test
    func serverActionDescriptorInvokesTypedDistributedFunction() async throws {
        try await withApplication { application in
            let service = RuntimeCounterService(actorSystem: .shared)
            let reference = service.incrementAction
            try await PageOwnedServices.register(service, on: application)
            let action = try application.swiftWebServerActions.action(
                actorName: reference.actorName,
                methodName: reference.methodName,
                metadata: ActionRequestMetadata(
                    actorID: reference.actorID,
                    actionName: reference.methodName,
                    targetIdentifier: reference.targetIdentifier
                )
            )
            let context = ActionInvocationContext(
                requestPath: reference.path,
                method: "POST",
                actorID: reference.actorID,
                actionName: reference.methodName,
                targetIdentifier: reference.targetIdentifier
            )
            let data = try await action.descriptor.invoke(
                on: action.actor,
                inputData: try JSONEncoder().encode(NoActionInput()),
                contextData: try JSONEncoder().encode(context)
            )

            let result = try JSONDecoder().decode(ActionResult.self, from: data)
            guard case .invalidate(let scope, let status) = result else {
                Issue.record("Server action invocation should invalidate the page")
                return
            }

            #expect(scope == .page)
            #expect(status == .ok)
            #expect(try await service.currentValue() == 1)
        }
    }

    @Test
    func actionReferenceCarriesStableInvocationIdentity() throws {
        let reference = ActionReference<NoActionInput, ActionResult>(
            actorID: "CounterService",
            actorName: "CounterService",
            methodName: "increment",
            targetIdentifier: "increment(_:context:)",
            inputType: "SwiftWeb.NoActionInput",
            outputType: "SwiftWeb.ActionResult",
            capabilityToken: "token"
        )

        let data = try JSONEncoder().encode(reference)
        let decoded = try JSONDecoder().decode(ActionReference<NoActionInput, ActionResult>.self, from: data)

        #expect(decoded.actorID == "CounterService")
        #expect(decoded.actorName == "CounterService")
        #expect(decoded.methodName == "increment")
        #expect(decoded.targetIdentifier == "increment(_:context:)")
        #expect(decoded.inputType == "SwiftWeb.NoActionInput")
        #expect(decoded.outputType == "SwiftWeb.ActionResult")
        #expect(decoded.capabilityToken == "token")
        #expect(decoded.path == "/_swiftweb/actions/CounterService/increment")
    }

    @Test
    func actionResultIsCodableForDistributedActorTransport() throws {
        let result = ActionResult.redirect("/counter")
        let data = try JSONEncoder().encode(result)
        let decoded = try JSONDecoder().decode(ActionResult.self, from: data)

        guard case .redirect(let location, let status) = decoded else {
            Issue.record("Decoded action result should be a redirect")
            return
        }
        #expect(location == "/counter")
        #expect(status == .seeOther)

        let invalidationData = try JSONEncoder().encode(ActionResult.invalidate(.page))
        let invalidation = try JSONDecoder().decode(ActionResult.self, from: invalidationData)
        guard case .invalidate(let scope, let invalidationStatus) = invalidation else {
            Issue.record("Decoded action result should be an invalidation")
            return
        }
        #expect(scope == .page)
        #expect(invalidationStatus == .ok)
    }

    @Test
    func invocationContextIsCodableAndDoesNotExposeRawRequest() throws {
        let context = ActionInvocationContext(
            requestPath: "/_swiftweb/actions/CounterService/increment",
            method: "POST",
            actorID: "CounterService",
            actionName: "increment",
            targetIdentifier: "increment(_:context:)",
            idempotencyKey: "request-key"
        )

        let data = try JSONEncoder().encode(context)
        let decoded = try JSONDecoder().decode(ActionInvocationContext.self, from: data)

        #expect(decoded.requestPath == context.requestPath)
        #expect(decoded.method == "POST")
        #expect(decoded.actorID == "CounterService")
        #expect(decoded.actionName == "increment")
        #expect(decoded.targetIdentifier == "increment(_:context:)")
        #expect(decoded.idempotencyKey == "request-key")
    }

    @Test
    func actionMetadataFieldsRenderRequiredGatewayMetadata() {
        let reference = ActionReference<NoActionInput, ActionResult>(
            actorID: "CounterService",
            actorName: "CounterService",
            methodName: "increment",
            targetIdentifier: "increment(_:context:)",
            inputType: "SwiftWeb.NoActionInput",
            outputType: "SwiftWeb.ActionResult",
            capabilityToken: "token"
        )

        let rendered = ActionMetadataFields(reference).render()

        #expect(rendered.contains("<input type=\"hidden\" name=\"__swiftweb_actor_id\" value=\"CounterService\">"))
        #expect(rendered.contains("<input type=\"hidden\" name=\"__swiftweb_action\" value=\"increment\">"))
        #expect(rendered.contains("<input type=\"hidden\" name=\"__swiftweb_target\" value=\"increment(_:context:)\">"))
        #expect(rendered.contains("<input type=\"hidden\" name=\"__swiftweb_action_token\" value=\"token\">"))
    }

    private func withApplication(
        _ body: (Application) async throws -> Void
    ) async throws {
        let application = try await Application()
        do {
            try await body(application)
            try await application.shutdown()
        } catch {
            try await application.shutdown()
            throw error
        }
    }
}

private distributed actor RuntimeCounterService {
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
}
