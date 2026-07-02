import SwiftHTML

package enum PaddingClassAxis: String, Sendable, CaseIterable {
    case all = "p"
    case top = "pt"
    case leading = "pl"
    case bottom = "pb"
    case trailing = "pr"
    case horizontal = "px"
    case vertical = "py"

    package func style(value: String) -> Style {
        switch self {
        case .all:
            .padding(value)
        case .top:
            .paddingTop(value)
        case .leading:
            .paddingLeft(value)
        case .bottom:
            .paddingBottom(value)
        case .trailing:
            .paddingRight(value)
        case .horizontal:
            Style {
                .paddingLeft(value)
                .paddingRight(value)
            }
        case .vertical:
            Style {
                .paddingTop(value)
                .paddingBottom(value)
            }
        }
    }
}
