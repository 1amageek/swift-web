import SwiftWebStyle
import SwiftWebUITheme

/// The SwiftWebUI document style bootstrap: the root stylesheet for the
/// process-wide style system plus the runtime scripts SwiftWebUI components
/// rely on (Liquid Glass refraction, slider sync).
///
/// The bootstrap installs itself the first time any SwiftWebUI component or
/// style modifier renders, so pages are styled without calling any modifier.
/// Apps that want a non-default style system call `install(styleSystem:)`
/// before serving the first page; the first installation wins.
public enum SwiftWebUIDocumentStyle {
    public static func install(styleSystem: StyleSystem = .liquidGlass) {
        DocumentStyleBootstrap.install(Provider(styleSystem: styleSystem))
    }

    static func installIfNeeded() {
        install()
    }

    private struct Provider: DocumentStyleBootstrapProvider {
        let styleSystem: StyleSystem

        var stylesheet: String {
            RootStylesheet.css(for: styleSystem)
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

        var styleSystemID: String {
            styleSystem.id
        }
    }
}
