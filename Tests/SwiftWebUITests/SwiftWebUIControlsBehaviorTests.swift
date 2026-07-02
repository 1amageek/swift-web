import Foundation
import SwiftHTML
import SwiftWebUI
import Synchronization
import Testing

@Suite
struct SwiftWebUIControlsBehaviorTests {
  @Test
  func formWithoutActionLowersToPlainContainer() {
    @State var title = "Draft"

    let rendered = Form {
      TextField("Title", text: $title)
    }
    .render()

    // Without an action the group must not be a real <form>; otherwise Enter
    // in the text field would implicitly submit a GET to the current URL.
    #expect(!rendered.contains("<form"))
    #expect(rendered.contains("<div class=\"swui-form\">"))
  }

  @Test
  func formWithoutActionKeepsServerActionButtonsWorking() {
    let rendered = Form {
      Button(
        "Increment",
        action: .post(
          "/counter",
          name: "delta",
          value: 1
        )
      )
    }
    .render()

    // The presentational group does not mark `isInsideForm`, so the action
    // button self-wraps in its own dedicated <form> and stays submittable.
    #expect(occurrenceCount(of: "<form", in: rendered) == 1)
    #expect(rendered.contains("swui-button-action-form"))
    #expect(rendered.contains("action=\"/counter\""))
    #expect(rendered.contains("<input type=\"hidden\" name=\"delta\" value=\"1\">"))
  }

  @Test
  func formWithActionRendersRealFormElement() {
    @State var title = "Draft"

    let rendered = Form(action: "/submit", method: .post) {
      TextField("Title", text: $title)
    }
    .render()

    #expect(rendered.contains("<form class=\"swui-form\" action=\"/submit\" method=\"post\">"))
  }

  @Test
  func textFieldWithoutPromptOmitsPlaceholder() {
    @State var title = ""

    let rendered = TextField("Title", text: $title).render()

    #expect(rendered.contains("<span class=\"swui-field-label\">Title</span>"))
    #expect(!rendered.contains("placeholder="))
  }

  @Test
  func textFieldPromptRendersAsPlaceholder() {
    @State var title = ""

    let rendered = TextField("Title", text: $title, prompt: Text("Enter a title")).render()

    #expect(rendered.contains("<span class=\"swui-field-label\">Title</span>"))
    #expect(rendered.contains("placeholder=\"Enter a title\""))
  }

  @Test
  func secureFieldWithoutPromptOmitsPlaceholder() {
    @State var secret = ""

    let rendered = SecureField("Password", text: $secret).render()

    #expect(rendered.contains("<span class=\"swui-field-label\">Password</span>"))
    #expect(rendered.contains("type=\"password\""))
    #expect(!rendered.contains("placeholder="))
  }

  @Test
  func secureFieldPromptRendersAsPlaceholder() {
    @State var secret = ""

    let rendered = SecureField("Password", text: $secret, prompt: Text("Required")).render()

    #expect(rendered.contains("placeholder=\"Required\""))
  }

  @Test
  func stepperCanonicalInitRendersWithoutValueDisplay() {
    @State var quantity = 4

    let rendered = Stepper("Qty", value: $quantity, in: 0...10, step: 2).render()

    #expect(rendered.contains("role=\"group\" aria-label=\"Qty\""))
    #expect(rendered.contains("<span class=\"swui-stepper-label\">Qty</span>"))
    #expect(rendered.contains("aria-label=\"Decrement Qty\""))
    #expect(rendered.contains("aria-label=\"Increment Qty\""))
    // The stepper renders no value readout; the title owns the display.
    #expect(!rendered.contains("swui-stepper-value"))
  }

  @Test
  func stepperWithoutBoundsRenders() {
    @State var quantity = 1

    let rendered = Stepper("Qty", value: $quantity, step: 5).render()

    #expect(rendered.contains("role=\"group\" aria-label=\"Qty\""))
    #expect(rendered.contains("aria-label=\"Decrement Qty\""))
    #expect(rendered.contains("aria-label=\"Increment Qty\""))
  }

  @Test
  func stepperClickPairsEditingChangedAroundValueUpdate() throws {
    @State var quantity = 1
    let recorder = EditingChangeRecorder()

    let artifact = Stepper(
      "Qty",
      value: $quantity,
      in: 0...10,
      onEditingChanged: { recorder.append($0) }
    )
    .renderArtifact()

    let clicks = artifact.clientHandlers.handlers.filter { $0.eventName == "click" }
    #expect(clicks.count == 2)

    // Buttons render in document order: decrement first, increment second.
    let decrement = try #require(clicks.first)
    decrement.invoke()
    #expect(quantity == 0)
    #expect(recorder.values == [true, false])

    let increment = try #require(clicks.last)
    increment.invoke()
    #expect(quantity == 1)
    #expect(recorder.values == [true, false, true, false])
  }

  @Test
  func sliderRegistersInputAndChangeListeners() {
    @State var volume = 0.5

    let rendered = Slider(value: $volume).render()

    #expect(rendered.contains("type=\"range\""))
    #expect(rendered.contains("data-event-input="))
    #expect(rendered.contains("data-event-change="))
  }

  @Test
  func sliderPairsEditingChangedAcrossInputAndChange() throws {
    @State var volume = 0.5
    let recorder = EditingChangeRecorder()

    let artifact = Slider(
      value: $volume,
      in: 0...1,
      onEditingChanged: { recorder.append($0) }
    )
    .renderArtifact()

    let input = try #require(artifact.clientHandlers.handlers.first { $0.eventName == "input" })
    let change = try #require(artifact.clientHandlers.handlers.first { $0.eventName == "change" })

    // A drag emits many input events; only the first reports editing start.
    input.invoke(with: DOMEvent(value: "0.25"))
    input.invoke(with: DOMEvent(value: "0.75"))
    #expect(volume == 0.75)
    #expect(recorder.values == [true])

    // Releasing the thumb fires the native change event and ends editing.
    change.invoke()
    #expect(recorder.values == [true, false])

    // A stray change without an active editing session reports nothing.
    change.invoke()
    #expect(recorder.values == [true, false])
  }

  @Test
  func onChangeZeroParameterClosureRunsOnInitialObservation() {
    let counter = InvocationCounter()

    _ = Text("Value")
      .onChange(of: 7, initial: true) {
        counter.increment()
      }
      .render()

    #expect(counter.count == 1)
  }

  @Test
  func colorPickerRetainsSupportsOpacityCallSites() {
    @State var color = "#3366ff"

    let opaque = ColorPicker("Accent", selection: $color, supportsOpacity: false).render()
    let translucent = ColorPicker("Accent", selection: $color, supportsOpacity: true).render()

    // The native color input cannot represent alpha, so both call forms lower
    // to the same opaque control; the parameter stays accepted for canonical
    // call-site compatibility.
    #expect(opaque.contains("type=\"color\""))
    #expect(opaque.contains("value=\"#3366ff\""))
    #expect(translucent.contains("type=\"color\""))
  }
}

private final class EditingChangeRecorder: Sendable {
  private let storage = Mutex([Bool]())

  var values: [Bool] {
    storage.withLock { $0 }
  }

  func append(_ value: Bool) {
    storage.withLock { $0.append(value) }
  }
}

private final class InvocationCounter: Sendable {
  private let storage = Mutex(0)

  var count: Int {
    storage.withLock { $0 }
  }

  func increment() {
    storage.withLock { $0 += 1 }
  }
}

private func occurrenceCount(of needle: String, in haystack: String) -> Int {
  guard !needle.isEmpty else {
    return 0
  }
  var count = 0
  var searchRange = haystack.startIndex..<haystack.endIndex
  while let found = haystack.range(of: needle, range: searchRange) {
    count += 1
    searchRange = found.upperBound..<haystack.endIndex
  }
  return count
}
