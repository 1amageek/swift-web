import SwiftHTML
import SwiftWeb
import SwiftWebUI

@Page("/")
struct HelloPage {
    init() {}

    var document: some HTMLDocument {
        PageDocument(
            title: "Hello World",
            description: "A minimal SwiftWeb application."
        ) {
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
}
