import Foundation
import SwiftHTML
import SwiftWebUI

/// One curated configuration of a component, shown in the page's variants
/// gallery. Variants are static (no knobs): they exist so a reader sees the
/// component's whole range at a glance before touching the playground.
///
/// Heterogeneous demos share one array by rendering to markup at card render
/// time. The nested `render()` runs under the ambient `StyleRegistry`, so
/// atomic classes land in the page stylesheet exactly like the DOM-contract
/// section's nested render.
struct CatalogVariant: Identifiable, Sendable {
    let id: String
    let title: String
    let detail: String
    private let renderDemo: @Sendable () -> String

    init(
        _ title: String,
        detail: String,
        @HTMLBuilder demo: () -> some HTML
    ) {
        self.id = title
        self.title = title
        self.detail = detail
        let content = demo()
        self.renderDemo = { content.render() }
    }

    func demoHTML() -> String {
        renderDemo()
    }
}

struct CatalogVariantsPanel: Component {
    let scene: StoryboardScene
    let variants: [CatalogVariant]

    var body: some HTML {
        div(.class("swui-storyboard-variants")) {
            ForEach(variants) { variant in
                CatalogVariantCard(scene: scene, variant: variant)
            }
        }
    }
}

struct CatalogVariantCard: Component {
    let scene: StoryboardScene
    let variant: CatalogVariant

    var body: some HTML {
        div(.class("swui-storyboard-variant")) {
            div(.class("swui-storyboard-variant-stage \(scene.className)")) {
                rawHTML(variant.demoHTML())
            }
            div(.class("swui-storyboard-variant-caption")) {
                Text(variant.title, as: .span)
                    .font(Font(size: .px(13), weight: .semibold))
                Text(variant.detail, as: .span)
                    .font(Font(size: .px(12)))
                    .foregroundStyle(.secondary)
            }
        }
    }
}
