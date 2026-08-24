import SwiftHTML
import SwiftWebUI

public struct ClientCounter: ClientComponent {
    @RemoteActor private var counter: CounterService
    @State private var value = 0
    @State private var isRequestPending = false
    @State private var failureMessage: String?

    public init() {}

    public var content: some Component {
        GroupBox {
            VStack(spacing: .large) {
                Text("Client Counter").as(.h2)
                Text(
                    "This ClientComponent calls the distributed actor directly and mirrors its returned value in WASM state."
                )
                .foregroundStyle(.secondary)
                VStack(spacing: .xsmall) {
                    Text("Client value").as(.small).foregroundStyle(.secondary)
                    Text(String(value)).as(.strong)
                        .font(.largeTitle)
                        .foregroundStyle(.accent)
                        .accessibilityIdentifier("counter-value")
                        .accessibilityValue(String(value))
                }
                LazyHStack(spacing: .small) {
                    Button("Decrement") {
                        decrement()
                    }
                    .disabled(isRequestPending)
                    Spacer()
                    Button("Increment") {
                        increment()
                    }
                    .disabled(isRequestPending)
                }
                if let failureMessage {
                    Text("Actor request failed: \(failureMessage)")
                        .accessibilityIdentifier("actor-error")
                }
            }
        }
        .accessibilityIdentifier("client-counter")
        .frame(maxWidth: .infinity, alignment: .top)
    }

    private func increment() {
        guard !isRequestPending else {
            return
        }
        let counter = self.counter
        isRequestPending = true
        Task { @MainActor in
            defer { isRequestPending = false }
            do {
                value = try await counter.increment()
                failureMessage = nil
            } catch {
                failureMessage = String(describing: error)
            }
        }
    }

    private func decrement() {
        guard !isRequestPending else {
            return
        }
        let counter = self.counter
        isRequestPending = true
        Task { @MainActor in
            defer { isRequestPending = false }
            do {
                value = try await counter.decrement()
                failureMessage = nil
            } catch {
                failureMessage = String(describing: error)
            }
        }
    }
}
