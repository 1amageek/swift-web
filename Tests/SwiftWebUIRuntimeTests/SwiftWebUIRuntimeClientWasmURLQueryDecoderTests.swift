import SwiftHTML
import SwiftWebUIRuntime
import Testing

private struct URLQuerySearchParams: Decodable, Equatable {
    let server: Int?
    let label: String
    let enabled: Bool
    let tags: [String]
}

private struct OptionalURLQuerySearchParams: Decodable, Equatable {
    let server: Int?
}

@Suite
struct SwiftWebUIRuntimeClientWasmURLQueryDecoderTests {
    @Test
    func decodesTypedSearchParamsFromBootstrapLocation() throws {
        let location = ClientWasmBootstrapLocation(
            href: "http://127.0.0.1:8080/counter?server=9&label=Hello%20World&enabled=true&tags=client&tags=wasm",
            search: "?server=9&label=Hello%20World&enabled=true&tags=client&tags=wasm"
        )

        let params = try location.decodeSearchParams(URLQuerySearchParams.self)

        #expect(params == URLQuerySearchParams(
            server: 9,
            label: "Hello World",
            enabled: true,
            tags: ["client", "wasm"]
        ))
    }

    @Test
    func missingOptionalSearchParamsDecodeAsNil() throws {
        let params = try ClientWasmURLQueryDecoder().decode(
            OptionalURLQuerySearchParams.self,
            from: ""
        )

        #expect(params == OptionalURLQuerySearchParams(server: nil))
    }
}
