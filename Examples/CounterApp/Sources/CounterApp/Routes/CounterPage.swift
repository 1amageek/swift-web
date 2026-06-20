import Distributed
import SwiftHTML
import SwiftWeb
import SwiftWebUI

@Page("/counter")
struct CounterPage {
    private let counterService = CounterService(actorSystem: .shared)

    init() {}

    var title: String {
        get async { "Counter" }
    }

    var description: String? {
        get async { "Client and server counters for validating SwiftWeb state, hydration, server actions, and distributed RPC." }
    }

    var cache: CachePolicy {
        .noStore
    }

    func load() async throws -> Int {
        try await counterService.currentValue()
    }

    func body(_ serverValue: Int) -> some HTML {
        main {
            GridSystem {
                Pane(span: 12) {
                    VStack(spacing: .xlarge) {
                        Grid {
                            ClientCounter()

                            GroupBox {
                                VStack(spacing: .large) {
                                    Heading("Server Counter")
                                    Text(
                                        "Each button posts a delta to Vapor. The value is read from server state on the next render.",
                                        tone: .muted
                                    )
                                    VStack(spacing: .xsmall) {
                                        Text("Server value", as: .small, tone: .muted)
                                        Text(String(serverValue), as: .strong)
                                            .font(.largeTitle)
                                            .foregroundStyle(.accent)
                                            .accessibilityIdentifier("counter-value")
                                            .accessibilityValue(String(serverValue))
                                    }
                                    LazyHStack(spacing: .small) {
                                        Button("Decrement", action: counterService.decrementAction)
                                        Spacer()
                                        Button("Increment", action: counterService.incrementAction)
                                    }
                                }
                            }
                            .accessibilityIdentifier("server-counter")
                            .frame(maxWidth: .infinity, alignment: .top)
                        }

                        Link("Reload page", href: "/counter")
                    }
                }
            }
            .frame(maxWidth: 920)
        }
        .environment(\.theme, .system)
    }
}
