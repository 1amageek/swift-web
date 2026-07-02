import SwiftHTML
import SwiftWebUI
import Testing

@Suite
struct SwiftWebUINavigationStackTests {
  @Test
  func navigationPathMirrorsSwiftUISurface() {
    var path = NavigationPath()
    #expect(path.isEmpty)
    path.append("files")
    path.append("readme")
    #expect(path.count == 2)
    path.removeLast()
    #expect(path.components == ["files"])
    path.removeLast(1)
    #expect(path.isEmpty)
  }

  @Test
  func navigationStackEmitsPathAttributes() {
    @State var path = NavigationPath(["files", "readme"])
    let rendered = NavigationStack(path: $path) {
      Text("root")
    }
    .render()
    #expect(rendered.contains("data-navigation-stack=\"true\""))
    #expect(rendered.contains("data-navigation-path=\"files/readme\""))
    #expect(rendered.contains("data-navigation-pushed=\"true\""))
  }

  @Test
  func emptyPathOmitsPushedMarker() {
    @State var path = NavigationPath()
    let rendered = NavigationStack(path: $path) {
      Text("root")
    }
    .render()
    #expect(rendered.contains("data-navigation-path=\"\""))
    #expect(!rendered.contains("data-navigation-pushed"))
  }

  @Test
  func navigationDestinationRendersTopSegmentAndHidesRoot() {
    @State var path = NavigationPath(["readme"])
    let rendered = NavigationStack(path: $path) {
      Text("root list")
        .navigationDestination(for: String.self) { name in
          Text("detail \(name)")
        }
    }
    .render()
    #expect(rendered.contains("data-navigation-origin=\"true\""))
    #expect(rendered.contains("data-navigation-destination=\"true\""))
    #expect(rendered.contains("detail readme"))
    #expect(rendered.contains("root list"))
  }

  @Test
  func navigationDestinationRendersRootWhenPathEmpty() {
    @State var path = NavigationPath()
    let rendered = NavigationStack(path: $path) {
      Text("root list")
        .navigationDestination(for: String.self) { name in
          Text("detail \(name)")
        }
    }
    .render()
    #expect(!rendered.contains("data-navigation-origin"))
    #expect(!rendered.contains("data-navigation-destination"))
    #expect(rendered.contains("root list"))
  }

  @Test
  func typedDestinationSkipsNonMatchingSegment() {
    @State var path = NavigationPath(["readme"])
    let rendered = NavigationStack(path: $path) {
      Text("root list")
        .navigationDestination(for: Int.self) { number in
          Text("page \(number)")
        }
    }
    .render()
    #expect(!rendered.contains("data-navigation-destination"))
    #expect(rendered.contains("root list"))
  }

  @Test
  func destinationOutsideStackRendersContentOnly() {
    let rendered = Text("standalone")
      .navigationDestination(for: String.self) { name in
        Text("detail \(name)")
      }
      .render()
    #expect(!rendered.contains("data-navigation-destination"))
    #expect(rendered.contains("standalone"))
  }
}
