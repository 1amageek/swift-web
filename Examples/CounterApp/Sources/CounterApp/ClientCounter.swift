import SwiftHTML
import SwiftWebUI

public struct ClientCounter: ClientComponent, Sendable {
    @State private var value = 0

    public init() {}

    public var body: some HTML {
        Card(.class("client-counter")) {
            VStack(spacing: .large) {
                Heading("Client Counter")
                Text(
                    "This state is owned by a ClientComponent running in WASM.",
                    tone: .muted
                )
                ValueDisplay(label: "Client value", value: value)
                LazyHStack(spacing: .small) {
                    Button("Decrement") {
                        value -= 1
                    }
                    Spacer()
                    Button("Increment") {
                        value += 1
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .top)
    }
}
