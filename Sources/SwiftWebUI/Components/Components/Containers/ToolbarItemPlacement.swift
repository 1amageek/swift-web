import SwiftHTML

/// A placement for toolbar content, mirroring SwiftUI's `ToolbarItemPlacement`.
///
/// Placements lower into four bar regions on the web: leading, principal
/// (centered), trailing, and the bottom bar. Placements that do not exist in a
/// browser (such as `.keyboard`) are intentionally not provided, so their use
/// fails at compile time instead of silently doing nothing.
public struct ToolbarItemPlacement: Sendable, Equatable {
    enum Region: String, Sendable, Equatable {
        case leading
        case principal
        case trailing
        case bottom
    }

    let region: Region

    public static let automatic = ToolbarItemPlacement(region: .trailing)
    public static let principal = ToolbarItemPlacement(region: .principal)
    public static let primaryAction = ToolbarItemPlacement(region: .trailing)
    public static let secondaryAction = ToolbarItemPlacement(region: .trailing)
    public static let confirmationAction = ToolbarItemPlacement(region: .trailing)
    public static let cancellationAction = ToolbarItemPlacement(region: .leading)
    public static let destructiveAction = ToolbarItemPlacement(region: .trailing)
    public static let navigation = ToolbarItemPlacement(region: .leading)
    public static let topBarLeading = ToolbarItemPlacement(region: .leading)
    public static let topBarTrailing = ToolbarItemPlacement(region: .trailing)
    public static let bottomBar = ToolbarItemPlacement(region: .bottom)
    public static let status = ToolbarItemPlacement(region: .bottom)
}

#if !hasFeature(Embedded)
extension ToolbarItemPlacement.Region: Codable {}
#endif
