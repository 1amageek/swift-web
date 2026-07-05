import Foundation
import SwiftHTML
import SwiftWebUI

// MARK: - Detail: Animation

struct AnimationDetail: Component {
    let selection: String
    /// Shared control-panel state, keyed "componentID.knob".
    let ui: Binding<[String: String]>

    private var state: [String: String] { ui.wrappedValue }
    private var on: Binding<Bool> { ui.bool("\(selection).on") }

    var body: some HTML {
        switch selection {
        case "transition":
            // Removal is animated by the runtime; insertion by CSS @starting-style.
            if on.wrappedValue {
                GroupBox {
                    Text("Now you see me")
                }
                .transition(transitionValue(state.control("transition", "kind")))
            }
        case "withanimation":
            // The button drives the change inside withAnimation, so the whole
            // update is interpolated with the selected timing.
            VStack(spacing: .medium) {
                Button(action: {
                    withAnimation(animationValue("withanimation")) {
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
        default: // animation
            // `.animation(_:value:)` interpolates the descendant changes a state
            // change drives, using the selected curve and duration.
            GroupBox {
                Text("Featured")
            }
            .opacity(on.wrappedValue ? 1 : 0.3)
            .scaleEffect(on.wrappedValue ? 1.08 : 1)
            .animation(animationValue("animation"), value: on.wrappedValue)
        }
    }

    private func animationValue(_ prefix: String) -> Animation {
        let curve = state.control(prefix, "curve")
        let duration = state.controlNumber(prefix, "duration")
        let bounce = state.controlFlag(prefix, "bounce")
        switch curve {
        case "easeIn": return .easeIn(duration: duration)
        case "easeOut": return .easeOut(duration: duration)
        case "linear": return .linear(duration: duration)
        case "spring": return .spring(duration: duration, bounce: bounce ? 0.3 : 0)
        default: return .easeInOut(duration: duration)
        }
    }

    private func transitionValue(_ kind: String) -> AnyTransition {
        switch kind {
        case "opacity": return .opacity
        case "move": return .move(edge: .bottom)
        case "slide": return .slide
        case "asymmetric": return .asymmetric(insertion: .move(edge: .leading), removal: .opacity)
        default: return .scale.combined(with: .opacity)
        }
    }
}
