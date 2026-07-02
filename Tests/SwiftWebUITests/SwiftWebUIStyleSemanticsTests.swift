import Foundation
import SwiftHTML
import SwiftWebUI
import Testing

@Suite
struct SwiftWebUIStyleSemanticsTests {
  @Test
  func backgroundStyleWritesEnvironmentWithoutPainting() {
    let rendered = Text("Styled")
      .backgroundStyle(.accent)
      .render()

    #expect(!rendered.contains("background:"))
    #expect(!rendered.contains("swui-style-background"))
  }

  @Test
  func backgroundInShapeFillsWithRootBackgroundByDefault() {
    let rendered = Text("Card")
      .background(in: .rect(cornerRadius: 8))
      .render()

    #expect(rendered.contains("background: var(--swui-background)"))
    #expect(rendered.contains("border-radius: 8px"))
  }

  @Test
  func backgroundInShapeFillsWithEnvironmentBackgroundStyle() {
    let rendered = Text("Card")
      .background(in: .capsule)
      .backgroundStyle(.accent)
      .render()

    #expect(rendered.contains("background: var(--swui-accent)"))
    #expect(rendered.contains("border-radius: var(--swui-radius-pill)"))
  }

  @Test
  func rectShapeHasSquareCorners() {
    let rendered = Text("Panel")
      .background(.regularMaterial, in: .rect)
      .render()

    #expect(rendered.contains("border-radius: 0px"))
    #expect(!rendered.contains("var(--swui-radius-medium)"))
  }

  @Test
  func containerRectShapeUsesThemeRadius() {
    let rendered = Text("Panel")
      .background(.regularMaterial, in: .containerRect)
      .render()

    #expect(rendered.contains("border-radius: var(--swui-radius-medium)"))
  }

  @Test
  func materialBackgroundWithoutShapeIsEdgeToEdge() {
    let rendered = Text("Bar")
      .background(.bar)
      .render()

    #expect(rendered.contains("swui-material-bar"))
    #expect(!rendered.contains("border-radius"))
  }

  @Test
  func standardColorsUseAdaptiveSystemPalette() {
    #expect(Color.red.cssValue == "light-dark(rgb(255, 59, 48), rgb(255, 69, 58))")
    #expect(Color.blue.cssValue == "light-dark(rgb(0, 122, 255), rgb(10, 132, 255))")
    #expect(Color.mint.cssValue == "light-dark(rgb(0, 199, 190), rgb(99, 230, 226))")
    #expect(Color.gray.cssValue == "light-dark(rgb(142, 142, 147), rgb(142, 142, 147))")
    #expect(Color.accentColor.cssValue == Color.accent.cssValue)
  }

  @Test
  func hsbInitializerLowersToHSL() {
    #expect(Color(hue: 0.5, saturation: 1, brightness: 1).cssValue == "hsl(180, 100%, 50%)")
    #expect(Color(hue: 0, saturation: 0, brightness: 0.5, opacity: 0.5).cssValue == "hsla(0, 0%, 50%, 0.5)")
  }

  @Test
  func hierarchicalSecondaryDerivesFromForegroundHierarchy() {
    let rendered = Text("Muted")
      .foregroundStyle(.secondary)
      .render()

    #expect(rendered.contains("color: var(--swui-foreground-secondary, var(--swui-text-muted))"))
  }

  @Test
  func hierarchicalTertiaryResolvesToForegroundVariable() {
    let rendered = Text("Faint")
      .foregroundStyle(.tertiary)
      .render()

    #expect(rendered.contains("color: var(--swui-foreground-tertiary"))
  }

  @Test
  func explicitColorSecondaryStaysFixedSemanticColor() {
    #expect(Color.secondary.cssValue == "var(--swui-text-muted)")

    let rendered = Text("Muted")
      .foregroundStyle(Color.secondary)
      .render()

    #expect(rendered.contains("color: var(--swui-text-muted)"))
  }

  @Test
  func hierarchicalLevelsSkipSelfReferentialCustomProperties() {
    let rendered = Text("Hierarchy")
      .foregroundStyle(.primary, .secondary, .accent)
      .render()

    #expect(rendered.contains("color: var(--swui-foreground-primary, var(--swui-text))"))
    #expect(!rendered.contains("--swui-foreground-primary:"))
    #expect(!rendered.contains("--swui-foreground-secondary:"))
    #expect(rendered.contains("--swui-foreground-tertiary: var(--swui-accent)"))
  }

  @Test
  func fontSystemComposesSizeWeightAndDesign() {
    let rendered = Text("Sized")
      .font(.system(size: .px(18), weight: .semibold, design: .monospaced))
      .render()

    #expect(rendered.contains("font-size: 18px"))
    #expect(rendered.contains("font-weight: 600"))
    #expect(rendered.contains("var(--swui-mono-font-family)"))
  }

  @Test
  func glassTintAcceptsColor() {
    let rendered = Text("Glass")
      .glassEffect(.regular.tint(.accent), in: .capsule)
      .render()

    #expect(rendered.contains("--swui-material-tint: var(--swui-accent)"))
  }

  @Test
  func tintEnvironmentCarriesResolvedColor() {
    let rendered = Gauge(value: 0.5) { "CPU" }
      .tint(.red)
      .render()

    #expect(rendered.contains("--swui-control-tint: light-dark(rgb(255, 59, 48), rgb(255, 69, 58))"))
  }
}
