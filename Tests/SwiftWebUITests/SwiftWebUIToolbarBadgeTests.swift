import SwiftHTML
import SwiftWebUI
import Testing

@Suite
struct SwiftWebUIToolbarBadgeTests {

  // MARK: - Helpers

  private struct ToolbarRegions {
    let leading: String
    let principal: String
    let trailing: String
    let bottom: String
  }

  /// Slices a rendered toolbar layout into its four regions using the stable
  /// zone and bar class markers, so placement tests assert membership rather
  /// than markup details.
  private func toolbarRegions(in rendered: String) throws -> ToolbarRegions {
    let leadingStart = try #require(rendered.range(of: "swui-toolbar-zone swui-toolbar-leading"))
    let principalStart = try #require(rendered.range(of: "swui-toolbar-zone swui-toolbar-principal"))
    let trailingStart = try #require(rendered.range(of: "swui-toolbar-zone swui-toolbar-trailing"))
    let headerEnd = try #require(rendered.range(of: "</header>"))
    let bottomStart = try #require(rendered.range(of: "swui-toolbar-bottom"))
    let footerEnd = try #require(rendered.range(of: "</footer>"))

    return ToolbarRegions(
      leading: String(rendered[leadingStart.upperBound..<principalStart.lowerBound]),
      principal: String(rendered[principalStart.upperBound..<trailingStart.lowerBound]),
      trailing: String(rendered[trailingStart.upperBound..<headerEnd.lowerBound]),
      bottom: String(rendered[bottomStart.upperBound..<footerEnd.lowerBound])
    )
  }

  private func occurrences(of needle: String, in haystack: String) -> Int {
    haystack.components(separatedBy: needle).count - 1
  }

  // MARK: - Toolbar placement

  @Test
  func toolbarNavigationPlacementRendersInLeadingZone() throws {
    let rendered = Text("Body")
      .toolbar {
        ToolbarItem(placement: .navigation) {
          Button("Back")
        }
      }
      .render()

    let regions = try toolbarRegions(in: rendered)
    #expect(regions.leading.contains("Back"))
    #expect(!regions.principal.contains("Back"))
    #expect(!regions.trailing.contains("Back"))
    #expect(!regions.bottom.contains("Back"))
  }

  @Test
  func toolbarAutomaticPlacementRendersInTrailingZone() throws {
    let rendered = Text("Body")
      .toolbar {
        ToolbarItem {
          Button("Save")
        }
      }
      .render()

    let regions = try toolbarRegions(in: rendered)
    #expect(regions.trailing.contains("Save"))
    #expect(!regions.leading.contains("Save"))
    #expect(!regions.principal.contains("Save"))
    #expect(!regions.bottom.contains("Save"))
  }

  @Test
  func toolbarPrincipalPlacementRendersInPrincipalZone() throws {
    let rendered = Text("Body")
      .toolbar {
        ToolbarItem(placement: .principal) {
          Text("Title")
        }
      }
      .render()

    let regions = try toolbarRegions(in: rendered)
    #expect(regions.principal.contains("Title"))
    #expect(!regions.leading.contains("Title"))
    #expect(!regions.trailing.contains("Title"))
    #expect(!regions.bottom.contains("Title"))
  }

  @Test
  func toolbarBottomBarPlacementRendersInFooter() throws {
    let rendered = Text("Body")
      .toolbar {
        ToolbarItem(placement: .bottomBar) {
          Text("Ready")
        }
      }
      .render()

    let regions = try toolbarRegions(in: rendered)
    #expect(regions.bottom.contains("Ready"))
    #expect(!regions.leading.contains("Ready"))
    #expect(!regions.principal.contains("Ready"))
    #expect(!regions.trailing.contains("Ready"))
  }

  @Test
  func toolbarItemGroupSharesOnePlacement() throws {
    let rendered = Text("Body")
      .toolbar {
        ToolbarItemGroup(placement: .navigation) {
          Button("Undo")
          Button("Redo")
        }
      }
      .render()

    let regions = try toolbarRegions(in: rendered)
    #expect(regions.leading.contains("swui-toolbar-item-group"))
    #expect(regions.leading.contains("Undo"))
    #expect(regions.leading.contains("Redo"))
    #expect(!regions.trailing.contains("Undo"))
    #expect(!regions.trailing.contains("Redo"))
  }

  @Test
  func toolbarEmitsBarAndZoneStructure() {
    let rendered = Text("Body")
      .toolbar {
        ToolbarItem {
          Button("Save")
        }
      }
      .render()

    #expect(rendered.contains("swui-toolbar-layout"))
    #expect(rendered.contains("swui-toolbar-top"))
    #expect(occurrences(of: "class=\"swui-toolbar-zone", in: rendered) == 3)
    #expect(rendered.contains("swui-toolbar-zone swui-toolbar-leading"))
    #expect(rendered.contains("swui-toolbar-zone swui-toolbar-principal"))
    #expect(rendered.contains("swui-toolbar-zone swui-toolbar-trailing"))
    #expect(rendered.contains("swui-toolbar-bottom"))
  }

  // MARK: - Badge

  @Test
  func badgeWrapsTheLabeledViewAndEmitsAPill() {
    let rendered = Text("Inbox")
      .badge("New")
      .render()

    #expect(rendered.contains("swui-badged"))
    #expect(rendered.contains("class=\"swui-badge swui-material swui-material-thin\""))
    #expect(rendered.contains("Inbox"))
    #expect(rendered.contains(">New</span>"))
  }

  @Test
  func badgeWithNilEmptyOrZeroRendersNoPill() {
    let renderedNil = Text("Inbox")
      .badge(nil)
      .render()
    let renderedEmpty = Text("Inbox")
      .badge("")
      .render()
    let renderedZero = Text("Inbox")
      .badge(0)
      .render()

    for rendered in [renderedNil, renderedEmpty, renderedZero] {
      #expect(!rendered.contains("swui-badge"))
      #expect(rendered.contains("Inbox"))
    }
  }

  @Test
  func badgeCountRendersTheNumber() {
    let rendered = Text("Updates")
      .badge(3)
      .render()

    #expect(rendered.contains("swui-badged"))
    #expect(rendered.contains("class=\"swui-badge swui-material swui-material-thin\""))
    #expect(rendered.contains(">3</span>"))
  }

  @Test
  func badgeInsideAListRowRendersThePill() {
    let rendered = List {
      ListRow {
        Text("Wi-Fi").badge("On")
      }
    }
    .render()

    #expect(rendered.contains("role=\"listitem\""))
    #expect(rendered.contains("swui-badged"))
    #expect(rendered.contains("class=\"swui-badge swui-material swui-material-thin\""))
    #expect(rendered.contains(">On</span>"))
  }
}
