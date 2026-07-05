import SwiftHTML
import SwiftWebStyle
import SwiftWebUI
import Testing

@Suite
struct DocumentStyleTests {
  @Test
  func preferredColorSchemeRecordsDocumentPreference() {
    let document = DocumentStyle()
    DocumentStyle.withCurrent(document) {
      _ = Text("x").preferredColorScheme(.dark).render()
    }
    #expect(document.preferredColorScheme == DocumentColorSchemePreference(rawValue: "dark"))
  }

  @Test
  func lastPreferredColorSchemeWriterWins() {
    let document = DocumentStyle()
    DocumentStyle.withCurrent(document) {
      _ = VStack {
        Text("a").preferredColorScheme(.dark)
        Text("b").preferredColorScheme(.light)
      }
      .render()
    }
    #expect(document.preferredColorScheme == DocumentColorSchemePreference(rawValue: "light"))
  }

  @Test
  func explicitNilPreferenceRecordsFollowUserAgent() {
    let document = DocumentStyle()
    DocumentStyle.withCurrent(document) {
      _ = Text("x").preferredColorScheme(.dark).preferredColorScheme(nil).render()
    }
    #expect(document.preferredColorScheme == DocumentColorSchemePreference(rawValue: nil))
  }

  @Test
  func renderingComponentsRequiresBootstrap() {
    let document = DocumentStyle()
    DocumentStyle.withCurrent(document) {
      _ = Text("x").render()
    }
    #expect(document.bootstrapRequired)
  }

  @Test
  func rawHTMLDoesNotRequireBootstrap() {
    let document = DocumentStyle()
    DocumentStyle.withCurrent(document) {
      _ = div { "plain" }.render()
    }
    #expect(!document.bootstrapRequired)
  }

  @Test
  func documentBootstrapProviderSuppliesRootAssets() throws {
    SwiftWebUIDocumentStyle.install()
    let provider = try #require(DocumentStyleBootstrap.installed)
    #expect(provider.rootClass == "swui-root")
    #expect(!provider.themeID.isEmpty)
    #expect(provider.stylesheet.contains(".swui-root"))
    #expect(provider.scripts.map(\.id).sorted() == ["swui-glass-refraction", "swui-slider-sync"])
  }

  @Test
  func preferredColorSchemeAppliesEnvironmentToSubtree() {
    let rendered = Text("x")
      .foregroundStyle(.accent)
      .preferredColorScheme(.dark)
      .styleRoot()
      .render()
    #expect(rendered.contains("color: var(--swui-accent)"))
  }
}
