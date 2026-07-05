import SwiftHTML
import SwiftWeb
import SwiftWebUI

@Page("/")
struct HelloPage {
    init() {}

    var title: String {
        get async { "Hello World" }
    }

    var description: String? {
        get async { "A minimal SwiftWeb application." }
    }

    func body() -> some HTML {
        main {
            GridSystem {
                Pane(span: 12) {
                    VStack(spacing: .large) {
                        Text("Hello, World!").as(.h1)
                        Text("This is the smallest SwiftWeb example.").foregroundStyle(.secondary)
                    }
                }
            }
            .frame(maxWidth: 720)
        }
        .preferredColorScheme(.light)
    }
}
