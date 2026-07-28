import SwiftWebUITheme
import SwiftHTML

public struct BackgroundModifier<Background: Component>: ComponentModifier {
    private let alignment: Alignment
    private let background: Background

    init(alignment: Alignment, @HTMLBuilder background: () -> Background) {
        self.init(alignment: alignment, background: background())
    }

    init(alignment: Alignment, background: Background) {
        self.alignment = alignment
        self.background = background
    }

    @ComponentBuilder
    public func content(_ content: ModifierContent) -> some Component {
        Element("div", attributes: [.class("swui-layered swui-background-layered")]) {
            Element("div", attributes: layerAttributes(kind: "background", alignment: alignment)) {
                background
            }
            Element("div", attributes: [.class("swui-layer swui-layer-content")]) {
                content
            }
        }
    }
}

public struct OverlayModifier<Overlay: Component>: ComponentModifier {
    private let alignment: Alignment
    private let overlay: Overlay

    init(alignment: Alignment, @HTMLBuilder overlay: () -> Overlay) {
        self.init(alignment: alignment, overlay: overlay())
    }

    init(alignment: Alignment, overlay: Overlay) {
        self.alignment = alignment
        self.overlay = overlay
    }

    @ComponentBuilder
    public func content(_ content: ModifierContent) -> some Component {
        Element("div", attributes: [.class("swui-layered swui-overlay-layered")]) {
            Element("div", attributes: [.class("swui-layer swui-layer-content")]) {
                content
            }
            Element("div", attributes: layerAttributes(kind: "overlay", alignment: alignment)) {
                overlay
            }
        }
    }
}

public extension Component {
    func background<Background: Component>(
        alignment: Alignment = .center,
        @HTMLBuilder content: () -> Background
    ) -> ModifiedContent {
        modifier(BackgroundModifier(alignment: alignment, background: content))
    }

    func background<Background: Component>(
        _ background: Background,
        alignment: Alignment = .center
    ) -> ModifiedContent {
        modifier(BackgroundModifier(alignment: alignment, background: background))
    }

    func overlay<Overlay: Component>(
        alignment: Alignment = .center,
        @HTMLBuilder content: () -> Overlay
    ) -> ModifiedContent {
        modifier(OverlayModifier(alignment: alignment, overlay: content))
    }

    func overlay<Overlay: Component>(
        _ overlay: Overlay,
        alignment: Alignment = .center
    ) -> ModifiedContent {
        modifier(OverlayModifier(alignment: alignment, overlay: overlay))
    }

    func overlay<S: ShapeStyle>(
        _ style: S,
        ignoresSafeAreaEdges edges: Edge.Set = .all
    ) -> ModifiedContent {
        modifier(StyleModifier(property: .overlay, style: style, ignoredSafeAreaEdges: edges))
    }
}

private func layerAttributes(kind: String, alignment: Alignment) -> [HTMLAttribute] {
    [
        .class("swui-layer swui-layer-\(kind)"),
        styleAttribute(Style {
            .justifySelf(alignment.horizontal.cssSelfAlignment)
            .alignSelf(alignment.vertical.cssSelfAlignment)
        }),
    ]
}
