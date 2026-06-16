import Distributed
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
        get async { "Client and server counters for validating SwiftWeb state, hydration, and distributed server actions." }
    }

    var cache: CachePolicy {
        .noStore
    }

    func load() async throws -> Int {
        try await counterService.currentValue()
    }

    func body(_ serverValue: Int) -> some HTML {
        VStack(spacing: .xlarge) {
            Grid {
                ClientCounter()

                Card(.class("server-counter")) {
                    VStack(spacing: .large) {
                        Heading("Server Counter")
                        Text(
                            "Each button posts a delta to Vapor. The value is read from server state on the next render.",
                            tone: .muted
                        )
                        ValueDisplay(label: "Server value", value: serverValue)
                        LazyHStack(spacing: .small) {
                            Button("Decrement", action: counterService.decrementAction)
                            Spacer()
                            Button("Increment", action: counterService.incrementAction)
                        }
                    }
                }
                .frame(maxWidth: .infinity, alignment: .top)
            }

            Link("Reload page", href: "/counter")
        }
        .frame(maxWidth: "920px")
        .padding(.horizontal, "var(--swui-page-inline-padding)")
        .padding(.vertical, .xlarge)
        .environment(\.theme, .system)
    }
}
