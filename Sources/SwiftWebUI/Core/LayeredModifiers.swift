import SwiftHTML

public struct BackgroundModifier<Background: HTML>: ComponentModifier {
    private let alignment: Alignment
    private let background: Background

    init(alignment: Alignment, @HTMLBuilder background: () -> Background) {
        self.alignment = alignment
        self.background = background()
    }

    @HTMLBuilder
    public func body(content: ModifierContent) -> some HTML {
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

public struct OverlayModifier<Overlay: HTML>: ComponentModifier {
    private let alignment: Alignment
    private let overlay: Overlay

    init(alignment: Alignment, @HTMLBuilder overlay: () -> Overlay) {
        self.alignment = alignment
        self.overlay = overlay()
    }

    @HTMLBuilder
    public func body(content: ModifierContent) -> some HTML {
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

public extension HTML {
    func background<Background: HTML>(
        alignment: Alignment = .center,
        @HTMLBuilder content: () -> Background
    ) -> ModifiedContent<Self, BackgroundModifier<Background>> {
        modifier(BackgroundModifier(alignment: alignment, background: content))
    }

    func background<Background: HTML>(
        _ background: Background,
        alignment: Alignment = .center
    ) -> ModifiedContent<Self, BackgroundModifier<Background>> {
        modifier(BackgroundModifier(alignment: alignment) { background })
    }

    func overlay<Overlay: HTML>(
        alignment: Alignment = .center,
        @HTMLBuilder content: () -> Overlay
    ) -> ModifiedContent<Self, OverlayModifier<Overlay>> {
        modifier(OverlayModifier(alignment: alignment, overlay: content))
    }

    func overlay<Overlay: HTML>(
        _ overlay: Overlay,
        alignment: Alignment = .center
    ) -> ModifiedContent<Self, OverlayModifier<Overlay>> {
        modifier(OverlayModifier(alignment: alignment) { overlay })
    }

    func overlay<ShapeStyle: WebShapeStyle>(
        _ style: ShapeStyle,
        ignoresSafeAreaEdges edges: Edge.Set = .all
    ) -> ModifiedContent<Self, WebStyleModifier<ShapeStyle>> {
        modifier(WebStyleModifier(property: .overlay, style: style, ignoredSafeAreaEdges: edges))
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
