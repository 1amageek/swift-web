import SwiftWebUITheme
import SwiftHTML

public enum ButtonProminence: Sendable, Equatable {
    case primary
    case secondary

    var className: String {
        switch self {
        case .primary:
            "swui-button swui-button-primary"
        case .secondary:
            "swui-button swui-button-secondary \(MaterialClass.material) \(MaterialClass.thin)"
        }
    }
}
