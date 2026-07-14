import Testing
@testable import SwiftWebCore

@Suite
struct URLEncodedFormDecoderTests {
    private struct SearchParams: Decodable, Equatable {
        let q: String
        let page: Int
        let exact: Bool?
        let tags: [String]?
    }

    @Test
    func decodesScalarsOptionalsAndArrays() throws {
        let decoder = URLEncodedFormDecoder()
        let decoded = try decoder.decode(
            SearchParams.self,
            from: "q=hello+world&page=2&exact=on&tags=swift&tags=web%2Fwasm"
        )
        #expect(decoded == SearchParams(q: "hello world", page: 2, exact: true, tags: ["swift", "web/wasm"]))
    }

    @Test
    func absentOptionalsDecodeAsNil() throws {
        let decoded = try URLEncodedFormDecoder().decode(SearchParams.self, from: "q=x&page=1")
        #expect(decoded.exact == nil)
        #expect(decoded.tags == nil)
    }

    @Test
    func missingRequiredKeyThrows() {
        #expect(throws: DecodingError.self) {
            try URLEncodedFormDecoder().decode(SearchParams.self, from: "page=1")
        }
    }

    @Test
    func percentDecodesNamesAndValues() throws {
        struct Form: Decodable {
            let message: String
        }
        let decoded = try URLEncodedFormDecoder().decode(
            Form.self,
            from: "message=%E3%81%93%E3%82%93%E3%81%AB%E3%81%A1%E3%81%AF%21"
        )
        #expect(decoded.message == "こんにちは!")
    }
}
