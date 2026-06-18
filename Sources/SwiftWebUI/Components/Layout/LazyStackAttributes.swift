import SwiftHTML

func lazyAttributes(axis: String, pinnedViews: PinnedScrollableViews) -> [HTMLAttribute] {
    var attributes: [HTMLAttribute] = [
        .data("lazy", axis),
    ]

    if pinnedViews.contains(.sectionHeaders) {
        attributes.append(.data("pinned-headers", "true"))
    }
    if pinnedViews.contains(.sectionFooters) {
        attributes.append(.data("pinned-footers", "true"))
    }

    return attributes
}
