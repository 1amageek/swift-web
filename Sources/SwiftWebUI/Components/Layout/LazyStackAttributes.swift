import SwiftHTML

func lazyAttributes(axis: String, pinnedViews: PinnedScrollableViews) -> [HTMLAttribute] {
    var attributes: [HTMLAttribute] = [
        .data("swift-web-ui-lazy", axis),
    ]

    if pinnedViews.contains(.sectionHeaders) {
        attributes.append(.data("swift-web-ui-pinned-headers", "true"))
    }
    if pinnedViews.contains(.sectionFooters) {
        attributes.append(.data("swift-web-ui-pinned-footers", "true"))
    }

    return attributes
}
