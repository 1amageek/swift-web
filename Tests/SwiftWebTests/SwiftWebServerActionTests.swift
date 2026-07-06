import Foundation
import SwiftHTML
@testable import SwiftWeb
@testable import SwiftWebCore
import Testing

@Suite
struct SwiftWebServerActionTests {
    @Test
    func serverActionDescriptorInvokesTypedActorHandler() async throws {
        try await withApplication { application in
            let service = RuntimeCounterService()
            try await PageOwnedServices.register(service, on: application)
            let action = try application.swiftWebServerActions.action(
                method: .post,
                path: "increment"
            )
            let context = ActionInvocationContext(
                requestPath: "/counter/increment",
                method: "POST"
            )
            let data = try await action.descriptor.invoke(
                on: action.handler,
                inputData: try JSONEncoder().encode(NoActionInput()),
                contextData: try JSONEncoder().encode(context)
            )

            let result = try JSONDecoder().decode(ActionResult.self, from: data)
            guard case .invalidate(let scope, let status) = result else {
                Issue.record("Server action invocation should invalidate the page")
                return
            }

            #expect(action.path == "increment")
            #expect(action.method == .post)
            #expect(scope == .page)
            #expect(status == .ok)
            #expect(await service.currentValue() == 1)
        }
    }

    @Test
    func serverActionDescriptorInvokesTypedClassHandler() async throws {
        try await withApplication { application in
            let handler = RuntimeClassActionHandler()
            try await PageOwnedServices.register(handler, on: application)
            let action = try application.swiftWebServerActions.action(
                method: .put,
                path: "submit"
            )
            let context = ActionInvocationContext(
                requestPath: "/class/submit",
                method: "PUT"
            )
            let data = try await action.descriptor.invoke(
                on: action.handler,
                inputData: try JSONEncoder().encode(TextActionInput(value: "saved")),
                contextData: try JSONEncoder().encode(context)
            )

            let result = try JSONDecoder().decode(ActionResult.self, from: data)
            guard case .redirect(let location, let status) = result else {
                Issue.record("Server action invocation should redirect")
                return
            }

            #expect(action.path == "submit")
            #expect(action.method == .put)
            #expect(location == "/class/saved")
            #expect(status == .seeOther)
        }
    }

    @Test
    func actionReferenceCarriesHTTPContract() throws {
        let reference = ActionReference<NoActionInput, ActionResult>(
            path: "/counter/increment",
            httpMethod: .post,
            inputType: "SwiftWeb.NoActionInput",
            outputType: "SwiftWeb.ActionResult"
        )

        let data = try JSONEncoder().encode(reference)
        let decoded = try JSONDecoder().decode(ActionReference<NoActionInput, ActionResult>.self, from: data)

        #expect(decoded.path == "/counter/increment")
        #expect(decoded.httpMethod == .post)
        #expect(decoded.method == .post)
        #expect(decoded.inputType == "SwiftWeb.NoActionInput")
        #expect(decoded.outputType == "SwiftWeb.ActionResult")
        #expect(decoded.fields.isEmpty)
    }

    @Test
    func deleteActionReferenceRendersMethodOverrideFieldForForms() {
        let reference = ActionReference<NoActionInput, ActionResult>(
            path: "/counter/increment",
            httpMethod: .delete
        )

        #expect(reference.method == .post)
        #expect(reference.fields == [ActionField("__swiftweb_method", "DELETE")])
    }

    @Test
    func actionResultIsCodableForServerActionTransport() throws {
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
            requestPath: "/counter/increment",
            method: "POST",
            idempotencyKey: "request-key"
        )

        let data = try JSONEncoder().encode(context)
        let decoded = try JSONDecoder().decode(ActionInvocationContext.self, from: data)

        #expect(decoded.requestPath == context.requestPath)
        #expect(decoded.method == "POST")
        #expect(decoded.idempotencyKey == "request-key")
    }

    @Test
    func actionMetadataFieldsRenderMethodOverrideOnlyWhenRequired() {
        let reference = ActionReference<NoActionInput, ActionResult>(
            path: "/counter/increment",
            httpMethod: .put
        )

        let rendered = ActionMetadataFields(reference).render()

        #expect(rendered.contains("<input type=\"hidden\" name=\"__swiftweb_method\" value=\"PUT\">"))
    }

    private func withApplication(
        _ body: (TestWebApplication) async throws -> Void
    ) async throws {
        try await body(TestWebApplication())
    }
}

private actor RuntimeCounterService {
    private var value = 0

    func currentValue() -> Int {
        value
    }

    @ServerAction(.post, "increment")
    func increment(_ input: NoActionInput, context: ActionInvocationContext) async throws -> ActionResult {
        value += 1
        return .invalidate(.page)
    }
}

private struct TextActionInput: Codable, Sendable {
    let value: String
}

private final class RuntimeClassActionHandler: Sendable {
    @ServerAction(.put, "submit")
    func submit(_ input: TextActionInput, context: ActionInvocationContext) throws -> ActionResult {
        .redirect("/class/\(input.value)")
    }
}
