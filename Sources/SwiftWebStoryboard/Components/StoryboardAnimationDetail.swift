import Foundation
import SwiftHTML
import SwiftWebUI

// MARK: - Detail: Animation

struct AnimationDetail: Component {
    let selection: String
    let on: Binding<Bool>

    var body: some HTML {
        switch selection {
        case "transition":
            // Removal is animated by the runtime; insertion by CSS @starting-style.
            if on.wrappedValue {
                GroupBox {
                    Text("Now you see me")
                }
                .transition(.scale.combined(with: .opacity))
            }
        case "withanimation":
            // The button drives the change inside withAnimation, so the whole update
            // is interpolated.
            VStack(spacing: .medium) {
                Button(action: {
                    withAnimation(.spring(duration: 0.4, bounce: 0.3)) {
                        on.wrappedValue.toggle()
                    }
                }) {
                    Text("Animate")
                }
                .buttonStyle(.borderedProminent)
                GroupBox {
                    Text("Springy")
                }
                .offset(x: on.wrappedValue ? 64 : 0)
            }
        default:
            // `.animation(_:value:)` interpolates the descendant changes a state
            // change drives.
            GroupBox {
                Text("Featured")
            }
            .opacity(on.wrappedValue ? 1 : 0.3)
            .scaleEffect(on.wrappedValue ? 1.08 : 1)
            .animation(.easeInOut(duration: 0.3), value: on.wrappedValue)
        }
    }
}
