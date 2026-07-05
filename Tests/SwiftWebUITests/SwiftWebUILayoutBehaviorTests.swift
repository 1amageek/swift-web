import Foundation
import SwiftHTML
import SwiftWebStyle
import SwiftWebUI
import Testing

@Suite
struct SwiftWebUILayoutBehaviorTests {
  @Test
  func spacerPublishesMinLengthAsAxisNeutralCustomProperty() {
    let rendered = VStack {
      Spacer(minLength: 24)
    }
    .render()

    // The spacer publishes its minimum length as a custom property instead of
    // hard-coding an inline min-width, so a VStack spacer keeps a min-height.
    #expect(rendered.contains("--swui-spacer-min-length: 24px"))
    #expect(!rendered.contains("min-width: 24px"))
  }

  @Test
  func rootStylesheetLowersSpacerMinLengthPerStackAxis() {
    let rendered = main {
      VStack {
        Spacer(minLength: 24)
      }
    }
    .styleRoot(.light)
    .environment(\.theme, .swiftWeb)
    .render()

    #expect(rendered.contains(".swui-vstack > .swui-spacer"))
    #expect(rendered.contains(".swui-lazy-vstack > .swui-spacer"))
    #expect(rendered.contains("min-height: var(--swui-spacer-min-length, 0px)"))
    #expect(rendered.contains(".swui-hstack > .swui-spacer"))
    #expect(rendered.contains(".swui-toolbar > .swui-spacer"))
    #expect(rendered.contains("min-width: var(--swui-spacer-min-length, 0px)"))
  }

  @Test
  func hiddenPreservesLayoutSpaceViaVisibility() {
    let hidden = Text("Ghost")
      .hidden()
      .render()
    let shown = Text("Ghost")
      .hidden(false)
      .render()

    // SwiftUI's hidden() keeps the view's layout space; visibility does that,
    // while the HTML `hidden` attribute (display: none) would collapse it.
    #expect(hidden.contains("visibility: hidden"))
    #expect(!hidden.contains("hidden="))
    #expect(!shown.contains("visibility: hidden"))
  }

  @Test
  func clipShapeClipsDescendantsWithOverflowHidden() {
    let rect = Text("Clip")
      .clipShape(.rect(cornerRadius: 8))
      .render()
    let capsule = Text("Clip")
      .clipShape(.capsule)
      .render()

    #expect(rect.contains("border-radius: 8px"))
    #expect(rect.contains("overflow: hidden"))
    #expect(capsule.contains("border-radius: var(--swui-radius-pill)"))
    #expect(capsule.contains("overflow: hidden"))
  }

  @Test
  func layoutPriorityMapsToCompressionResistance() {
    let prioritized = Text("Keep")
      .layoutPriority(1)
      .render()
    let defaulted = Text("Default")
      .layoutPriority(0)
      .render()

    // A positive priority resists compression; it must not make the view
    // greedy (flex-grow), which is not what SwiftUI's layoutPriority means.
    #expect(prioritized.contains("flex-shrink: 0"))
    #expect(!prioritized.contains("flex-grow"))
    #expect(!defaulted.contains("flex-shrink"))
    #expect(!defaulted.contains("flex-grow"))
  }

  @Test
  func disabledComposesWithAndSemantics() {
    // A descendant `.disabled(false)` cannot re-enable a subtree an ancestor
    // disabled: the outer modifier applies last, so the inner one reads the
    // ancestor environment and must AND it with its own flag.
    let reenableAttempt = Button("Save") {}
      .disabled(false)
      .disabled(true)
      .render()
    let innerDisable = Button("Save") {}
      .disabled(true)
      .disabled(false)
      .render()
    let enabled = Button("Save") {}
      .disabled(false)
      .render()

    #expect(reenableAttempt.contains("aria-disabled=\"true\""))
    #expect(innerDisable.contains("aria-disabled=\"true\""))
    #expect(!enabled.contains("aria-disabled=\"true\""))
  }

  @Test
  func textSelectabilityControlsUserSelect() {
    let selectable = Text("Copy me")
      .textSelection(TextSelectability.enabled)
      .render()
    let unselectable = Text("Chrome")
      .textSelection(.disabled)
      .render()

    #expect(selectable.contains("user-select: text"))
    #expect(unselectable.contains("user-select: none"))
  }

  @Test
  func textDecorationsAcceptSemanticColors() {
    let rendered = Text("Decorated")
      .underline(pattern: .dash, color: .accent)
      .strikethrough(pattern: .dot, color: .danger)
      .render()

    #expect(rendered.contains("text-decoration-color: var(--swui-accent)"))
    #expect(rendered.contains("text-decoration-color: var(--swui-danger)"))
  }

  @Test
  func shadowAcceptsSemanticColorsAndKeepsDefault() {
    let tinted = Text("Shadowed")
      .shadow(color: .accent, radius: 2)
      .render()
    let defaulted = Text("Shadowed")
      .shadow(radius: 4)
      .render()

    #expect(tinted.contains("box-shadow: 0px 0px 2px var(--swui-accent)"))
    #expect(defaulted.contains("box-shadow: 0px 0px 4px rgba(0, 0, 0, 0.33)"))
  }

  @Test
  func stackSpacingNoneResolvesToDefaultSystemSpacing() {
    // `spacing: .none` must resolve to `Double?.none` (SwiftUI's nil = default
    // system spacing), not `Space.none` (a zero gap).
    let vertical = VStack(spacing: .none) {
      Text("A")
    }
    .render()
    let horizontal = HStack(spacing: .none) {
      Text("A")
    }
    .render()

    #expect(vertical.contains("swui-gap-stack"))
    #expect(!vertical.contains("swui-gap-none"))
    #expect(horizontal.contains("swui-gap-stack"))
    #expect(!horizontal.contains("swui-gap-none"))
  }

  @Test
  func pinnedSectionHeadersAndFootersEmitStickyRules() {
    let rendered = main {
      LazyVStack(pinnedViews: [.sectionHeaders, .sectionFooters]) {
        Section("Inventory", footer: "End of inventory") {
          Text("Row")
        }
      }
    }
    .styleRoot(.light)
    .environment(\.theme, .swiftWeb)
    .render()

    #expect(rendered.contains("data-pinned-headers=\"true\""))
    #expect(rendered.contains("data-pinned-footers=\"true\""))
    #expect(rendered.contains("margin: 0;\n  padding: 10px 0 6px 0;"))
    #expect(!rendered.contains("padding: 10px 14px 6px 14px;"))
    let headerRule = cssRule(
      "[data-pinned-headers=\"true\"] > .swui-section > .swui-section-header",
      in: rendered
    )
    #expect(headerRule?.contains("position: sticky") == true)
    #expect(headerRule?.contains("top: 0") == true)
    let footerRule = cssRule(
      "[data-pinned-footers=\"true\"] > .swui-section > .swui-section-footer",
      in: rendered
    )
    #expect(footerRule?.contains("position: sticky") == true)
    #expect(footerRule?.contains("bottom: 0") == true)
  }

  @Test
  func uniformGridItemAlignmentLowersToContainerAlignment() {
    let uniform = LazyVGrid(columns: [
      GridItem(.flexible(), alignment: .topLeading),
      GridItem(.flexible(), alignment: .topLeading),
    ]) {
      Text("Cell")
    }
    .render()
    let mixed = LazyVGrid(columns: [
      GridItem(.flexible(), alignment: .topLeading),
      GridItem(.flexible(), alignment: .center),
    ]) {
      Text("Cell")
    }
    .render()

    // Uniform per-item alignment is the only case CSS Grid can express (as
    // container-level justify-items/align-items); mixed alignments stay
    // unlowered per the documented web contract.
    #expect(uniform.contains("justify-items: flex-start"))
    #expect(uniform.contains("align-items: flex-start"))
    #expect(!mixed.contains("justify-items:"))
  }

  private func cssRule(_ selector: String, in rendered: String) -> String? {
    guard let start = rendered.range(of: "\(selector) {"),
          let end = rendered[start.upperBound...].range(of: "}")
    else {
      return nil
    }
    return String(rendered[start.lowerBound..<end.upperBound])
  }
}
