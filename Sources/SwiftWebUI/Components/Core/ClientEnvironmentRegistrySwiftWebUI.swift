import SwiftWebUITheme
import SwiftHTML

extension ClientEnvironmentRegistry {
    /// Every client-snapshot environment key that SwiftWebUI can serialize.
    ///
    /// During server rendering, environment values whose key conforms to
    /// `ClientEnvironmentKey` are written into the client environment snapshot.
    /// The WASM runtime decodes that snapshot at hydration through this registry.
    /// A key that is missing here makes `ClientEnvironmentRegistry.environment(from:)`
    /// throw `missingDecoder`, which aborts hydration and disables every
    /// interactive control on the page. Keep this list exhaustive: register a key
    /// here whenever a new `ClientEnvironmentKey` is added to SwiftWebUI.
    ///
    /// The keys are `internal` (not `private`) so that `String(reflecting:)`
    /// yields a stable `SwiftWebUI.<Name>` identity that matches across the
    /// separately compiled server and WASM binaries. A `private` key reflects to
    /// `SwiftWebUI.(unknown context at $<address>).<Name>`, whose discriminator
    /// differs per binary and never matches the snapshot produced by the server.
    public static let swiftWebUI = ClientEnvironmentRegistry.standard
        .registering(ThemeEnvironmentKey.self)
        .registering(IsEnabledEnvironmentKey.self)
        .registering(ControlSizeEnvironmentKey.self)
        .registering(ControlStateEnvironmentKey.self)
        .registering(TintEnvironmentKey.self)
        .registering(BackgroundStyleEnvironmentKey.self)
        .registering(ButtonStyleEnvironmentKey.self)
        .registering(PickerStyleEnvironmentKey.self)
        .registering(ToggleStyleEnvironmentKey.self)
        .registering(TextFieldStyleEnvironmentKey.self)
        .registering(LabelStyleEnvironmentKey.self)
        .registering(ListStyleEnvironmentKey.self)
        .registering(FormStyleEnvironmentKey.self)
        .registering(MenuStyleEnvironmentKey.self)
        .registering(ProgressViewStyleEnvironmentKey.self)
        .registering(GaugeStyleEnvironmentKey.self)
        .registering(TabViewStyleEnvironmentKey.self)
        .registering(IsInsideFormEnvironmentKey.self)
        .registering(TabSelectionEnvironmentKey.self)
        .registering(TabGroupNameEnvironmentKey.self)
        .registering(ToolbarRegionEnvironmentKey.self)
        .registering(NavigationPathSegmentsEnvironmentKey.self)
        .registering(PickerSelectionEnvironmentKey.self)
        .registering(PickerGroupNameEnvironmentKey.self)
        .registering(SearchScopeSelectionEnvironmentKey.self)
        .registering(SearchScopeGroupNameEnvironmentKey.self)
        .registering(InteractiveDismissDisabledEnvironmentKey.self)
}
