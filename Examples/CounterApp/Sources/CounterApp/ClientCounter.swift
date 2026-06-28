import SwiftHTML
import SwiftWebUI

public struct ClientCounter: ClientComponent, Sendable {
    @Actor private var counter: any CounterServiceProtocol
    @State private var value = 0

    public init() {}

    public var body: some HTML {
        GroupBox {
            VStack(spacing: .large) {
                Heading("Client Counter")
                Text(
                    "This state is owned by a ClientComponent running in WASM."
                )
                .foregroundStyle(.secondary)
                VStack(spacing: .xsmall) {
                    Text("Client value", as: .small).foregroundStyle(.secondary)
                    Text(String(value), as: .strong)
                        .font(.largeTitle)
                        .foregroundStyle(.accent)
                        .accessibilityIdentifier("counter-value")
                        .accessibilityValue(String(value))
                }
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
        .accessibilityIdentifier("client-counter")
        .frame(maxWidth: .infinity, alignment: .top)
    }
}
