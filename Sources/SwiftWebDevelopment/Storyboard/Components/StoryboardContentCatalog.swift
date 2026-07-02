import Foundation

// The per-page editorial content (discussion, SwiftUI parity, variants) is
// split by category group so each group can grow independently. Pages without
// authored content fall back gracefully: no discussion means the summary
// stands alone, and no variants means the gallery section is omitted.

func catalogDiscussion(for id: String) -> [String] {
    foundationsDiscussion(for: id)
        ?? contentLayoutDiscussion(for: id)
        ?? menusNavigationDiscussion(for: id)
        ?? inputPresentationDiscussion(for: id)
        ?? statusAnimationDiscussion(for: id)
        ?? []
}

func catalogSwiftUIParity(for id: String) -> String? {
    foundationsParity(for: id)
        ?? contentLayoutParity(for: id)
        ?? menusNavigationParity(for: id)
        ?? inputPresentationParity(for: id)
        ?? statusAnimationParity(for: id)
}

func catalogVariants(for id: String) -> [CatalogVariant] {
    foundationsVariants(for: id)
        ?? contentLayoutVariants(for: id)
        ?? menusNavigationVariants(for: id)
        ?? inputPresentationVariants(for: id)
        ?? statusAnimationVariants(for: id)
        ?? []
}
