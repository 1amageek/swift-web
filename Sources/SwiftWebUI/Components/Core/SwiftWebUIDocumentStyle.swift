import SwiftWebStyle
import SwiftWebUITheme

/// The SwiftWebUI document style bootstrap: the root stylesheet for the
/// process-wide theme plus the runtime scripts SwiftWebUI components
/// rely on (Liquid Glass refraction, slider sync).
///
/// The bootstrap installs itself the first time any SwiftWebUI component or
/// style modifier renders, so pages are styled without calling any modifier.
/// Apps that want a non-default theme call `install(theme:)`
/// before serving the first page; the first installation wins.
public enum SwiftWebUIDocumentStyle {
    public static func install(theme: Theme = .liquidGlass) {
        DocumentStyleBootstrap.install(Provider(theme: theme))
    }

    static func installIfNeeded() {
        install()
    }

    private struct Provider: DocumentStyleBootstrapProvider {
        let theme: Theme

        var stylesheet: String {
            RootStylesheet.css(for: theme)
        }

        var scripts: [DocumentStyleScript] {
            [
                DocumentStyleScript(
                    id: "swui-glass-refraction",
                    body: StyleRootAssets.refractionScript
                ),
                DocumentStyleScript(
                    id: "swui-slider-sync",
                    body: StyleRootAssets.sliderScript
                ),
            ]
        }

        var rootClass: String {
            "swui-root"
        }

        var themeID: String {
            theme.id
        }
    }
}
