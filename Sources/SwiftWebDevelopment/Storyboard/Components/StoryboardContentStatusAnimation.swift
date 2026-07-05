import Foundation
import SwiftHTML
import SwiftWebUI

// Editorial content for the Status and Animation categories.
// The status pages (progressview, gauge, badge) show the components live. The
// animation pages are static under the variants contract, so they teach the
// vocabulary — timing curves, transition endpoints, event granularity — and
// leave the motion itself to the playground.

func statusAnimationDiscussion(for id: String) -> [String]? {
    switch id {
    case "progressview":
        return [
            "ProgressView shows how far a task has advanced. With a value it renders a determinate bar — the web lowering is a native <progress> element whose track composes the shared ultra-thin material, so the fill follows the active design style. Without a value it renders an indeterminate circular spinner driven purely by CSS animation.",
            "Prefer a determinate value whenever the work is measurable; value is read against total (1.0 by default), so fractions and absolute unit counts both work. A string label renders above the bar and doubles as the control's accessibility label.",
        ]
    case "gauge":
        return [
            "Gauge is a compact readout of a value within a range — battery level, signal strength, a sensor reading. The web lowering is a native <meter> element whose track composes the shared ultra-thin material, so the fill follows the active design style. Bounds default to 0...1, and in: accepts any closed range, so raw domain values need no normalizing.",
            "A gauge reports a current level, not task completion — reach for ProgressView when the value means how much work is done. .tint(_:) recolors the fill per gauge without touching the color scheme.",
        ]
    case "badge":
        return [
            "badge(_:) attaches a compact trailing pill to the view it labels — its standard home is a List row, where the pill carries a count or a short status. The wrapper is layout-transparent (display: contents), so inside the row's horizontal flow the pill lands at the trailing edge without any extra layout.",
            "The string and count overloads share one hiding rule: nil, an empty string, or a count of zero renders no badge at all rather than an empty pill, so rows can declare a badge unconditionally. The pill composes the thin material, and .tint(_:) feeds it a per-badge color.",
        ]
    case "animation":
        return [
            "animation(_:value:) declares how changes inside a subtree are interpolated when state drives them. The web lowering publishes the timing — duration, curve, delay — as the inherited --swui-animation custom property over a display: contents scope; when the runtime patches the DOM after an event, the browser transitions any animatable property that changed. There is no Swift-side animation engine and no frame loop — the declaration is inert until state actually changes.",
            "The Animation vocabulary lowers directly to CSS timing: the ease curves and .linear map to transition timing functions, springs are approximated as a sampled linear() easing so bounce survives the trip, and .delay(_:) and .speed(_:) derive new timings arithmetically. animation(nil) lowers to a zero-duration transition that overrides any ancestor scope.",
        ]
    case "transition":
        return [
            "transition(_:) describes how a view enters and leaves while an if or switch toggles its presence. Each transition is a pair of endpoint states: insertion animates from the transition's from state to normal purely in CSS via @starting-style, while removal is runtime-assisted — the element carries data-swui-transition and data-swui-exit-ms markers so the runtime can play the exit and detach the node only after it finishes.",
            "The vocabulary composes: .opacity, .scale(_:anchor:), .move(edge:), and .offset(_:) are the primitives, combined(with:) merges endpoint states, asymmetric(insertion:removal:) splits enter from exit — .slide is exactly that pair, leading in and trailing out — and .animation(_:) picks the timing, defaulting to .easeInOut over 0.3 seconds. The cards below render the resting state; toggle presence in the playground to see the motion.",
        ]
    case "withanimation":
        return [
            "withAnimation(_:_:) runs a closure and records its animation on the current transaction; when the runtime applies the event's resulting DOM changes, it hands the browser that timing, so the update is interpolated. As everywhere in the framework, the browser does the animating — there is no Swift-side engine, and outside a dispatched event (a server render) there is no transaction, so the closure simply runs unanimated.",
            "Granularity differs from SwiftUI by design: the web applies an event's changes only after the whole event is handled, so the recorded animation covers the entire resulting update, not just the closure's own writes. If several withAnimation calls run in one event, the last one wins for the whole update — use one call per event when timings must differ. withAnimation(nil) opts the update out explicitly.",
        ]
    default:
        return nil
    }
}

func statusAnimationParity(for id: String) -> String? {
    switch id {
    case "progressview":
        return "Same shape as SwiftUI's ProgressView(value:total:label:) — a nil value renders the indeterminate spinner; the web lowering is a native <progress> element plus a CSS spinner."
    case "gauge":
        return "Same shape as SwiftUI's Gauge(value:in:label:); the web lowering is a native <meter> element, with gaugeStyle(_:) selecting the presentation."
    case "badge":
        return "Same shape as SwiftUI's badge(_:) string and count overloads on list rows, including the nil/empty/zero hiding semantics."
    case "animation":
        return "Same shape as SwiftUI's animation(_:value:), with one web difference: the timing is not gated on value — it applies to any animatable change a descendant makes while in scope, and value is kept for API parity."
    case "transition":
        return "Same shape as SwiftUI's transition(_:) and its combinators; on the web, insertion lowers to CSS @starting-style and removal is timed by the runtime before the node detaches."
    case "withanimation":
        return "Same shape as SwiftUI's withAnimation(_:_:), but the scope is per event rather than per closure — the recorded animation applies to the whole resulting update, and the last call in an event wins."
    default:
        return nil
    }
}

func statusAnimationVariants(for id: String) -> [CatalogVariant]? {
    switch id {
    case "progressview":
        return [
            CatalogVariant("Indeterminate", detail: "No value renders the circular spinner, driven purely by CSS.") {
                ProgressView()
            },
            CatalogVariant("Determinate values", detail: "value: fills the native <progress> bar against total (1 by default).") {
                VStack(spacing: .small) {
                    ProgressView(value: 0.25).frame(width: 180)
                    ProgressView(value: 0.6).frame(width: 180)
                    ProgressView(value: 0.9).frame(width: 180)
                }
            },
            CatalogVariant("Labeled", detail: "The label renders above the bar and doubles as the accessibility label.") {
                ProgressView("Loading", value: 0.6).frame(width: 180)
            },
        ]
    case "gauge":
        return [
            CatalogVariant("Value in range", detail: "The value fills the native <meter> against the default 0...1 bounds.") {
                VStack(spacing: .small) {
                    Gauge(value: 0.25) { Text("Low") }.frame(width: 180)
                    Gauge(value: 0.6) { Text("Half") }.frame(width: 180)
                    Gauge(value: 0.9) { Text("High") }.frame(width: 180)
                }
            },
            CatalogVariant("Custom bounds & tint", detail: "in: takes raw domain values; .tint(_:) recolors the fill per gauge.") {
                VStack(spacing: .small) {
                    Gauge(value: 82, in: 0...100) { Text("Battery") }
                        .tint(.green)
                        .frame(width: 180)
                    Gauge(value: 12, in: 0...100) { Text("Battery") }
                        .tint(.danger)
                        .frame(width: 180)
                }
            },
        ]
    case "badge":
        return [
            CatalogVariant("Status text", detail: "A short status string in the pill at the row's trailing edge.") {
                List {
                    Text("Wi-Fi").badge("On")
                    Text("VPN").badge("Connected")
                }
                .frame(width: 180)
            },
            CatalogVariant("Counts", detail: "The Int overload renders the count, matching SwiftUI's semantics.") {
                List {
                    Text("Inbox").badge(3)
                    Text("Junk").badge(12)
                }
                .frame(width: 180)
            },
            CatalogVariant("Tinted", detail: ".tint(_:) colors the pill without touching the color scheme.") {
                List {
                    Text("Updates").badge("Beta").tint(.danger)
                    Text("Messages").badge(5).tint(.green)
                }
                .frame(width: 180)
            },
            CatalogVariant("Zero hides", detail: ".badge(0) renders no pill, so rows can declare badges unconditionally.") {
                List {
                    Text("Inbox").badge(3)
                    Text("Drafts").badge(0)
                }
                .frame(width: 180)
            },
        ]
    case "animation":
        return [
            CatalogVariant("Timing curves", detail: "The built-in curves at the standard 0.35s; each lowers to a CSS transition timing function.") {
                VStack(spacing: .xsmall) {
                    HStack(spacing: .xsmall) {
                        vocabularyChip(".easeInOut", "0.35s")
                        vocabularyChip(".easeIn", "0.35s")
                    }
                    HStack(spacing: .xsmall) {
                        vocabularyChip(".easeOut", "0.35s")
                        vocabularyChip(".linear", "0.35s")
                    }
                }
            },
            CatalogVariant("Springs", detail: "Springs lower to a sampled CSS linear() easing; bounce adds overshoot.") {
                VStack(spacing: .xsmall) {
                    vocabularyChip(".spring", "0.5s · bounce 0")
                    vocabularyChip(".spring(bounce: 0.3)", "0.5s · overshoots")
                }
            },
            CatalogVariant("Derived timing", detail: "duration:, .delay(_:), and .speed(_:) rescale the timing arithmetically.") {
                VStack(spacing: .xsmall) {
                    vocabularyChip(".easeOut(duration: 0.6)", "longer")
                    vocabularyChip(".delay(0.2)", "starts late")
                    vocabularyChip(".speed(2)", "half the time")
                }
            },
            CatalogVariant("Applied scope", detail: "The modifier adds no box: a display: contents wrapper publishes --swui-animation over the subtree.") {
                GroupBox {
                    Text("Featured")
                }
                .animation(.easeInOut(duration: 0.3), value: 0)
            },
        ]
    case "transition":
        return [
            CatalogVariant(".opacity", detail: "Fades in on insertion and out on removal.") {
                vocabularyChip(".opacity", "in 0 → 1 · out 1 → 0")
                    .transition(.opacity)
            },
            CatalogVariant(".scale", detail: "Grows from nothing and shrinks back; scale(_:anchor:) picks the origin.") {
                vocabularyChip(".scale", "scale(0) ↔ scale(1)")
                    .transition(.scale)
            },
            CatalogVariant(".move & .slide", detail: "Edge moves translate by the view's own extent; .slide is the built-in leading-in, trailing-out pair.") {
                VStack(spacing: .xsmall) {
                    vocabularyChip(".move(edge: .bottom)", "translateY(100%)")
                        .transition(.move(edge: .bottom))
                    vocabularyChip(".slide", "in leading · out trailing")
                        .transition(.slide)
                }
            },
            CatalogVariant("Combined & asymmetric", detail: "combined(with:) merges endpoint states; asymmetric(insertion:removal:) splits enter from exit.") {
                VStack(spacing: .xsmall) {
                    vocabularyChip(".combined(with:)", "scale + opacity merged")
                        .transition(.scale.combined(with: .opacity))
                    vocabularyChip(".asymmetric(…)", "insertion ≠ removal")
                        .transition(.asymmetric(insertion: .move(edge: .leading), removal: .opacity))
                }
            },
        ]
    case "withanimation":
        return [
            CatalogVariant("Animate an event", detail: "State changes made in the closure are patched to the DOM with the recorded timing.") {
                vocabularyChip("withAnimation(.spring) { … }", "records the timing on the event's transaction")
            },
            CatalogVariant("Per event, last wins", detail: "Two calls in one event: the last recorded animation applies to the entire update.") {
                VStack(spacing: .xsmall) {
                    vocabularyChip("withAnimation(.easeIn) { … }", "overridden")
                        .opacity(0.45)
                    vocabularyChip("withAnimation(.spring) { … }", "wins for the whole update")
                }
            },
            CatalogVariant("withAnimation(nil)", detail: "nil opts out; outside an event there is no transaction, so the closure runs unanimated too.") {
                vocabularyChip("withAnimation(nil) { … }", "runs unanimated")
            },
        ]
    default:
        return nil
    }
}

/// A static vocabulary card: a symbol rendered as code over a short meaning.
/// Used by the animation-family pages, whose variants name the vocabulary
/// instead of faking motion — the playground is where the values change.
private func vocabularyChip(_ symbol: String, _ meaning: String) -> some HTML {
    VStack(spacing: 2) {
        Text(symbol).as(.code)
            .font(.caption)
            .fontWeight(.semibold)
        Text(meaning).as(.span)
            .font(.caption2)
            .foregroundStyle(.secondary)
    }
    .padding(.all, 8)
    .background(.surfaceRaised)
    .border(.border)
    .clipShape(.rect(cornerRadius: 8))
}
