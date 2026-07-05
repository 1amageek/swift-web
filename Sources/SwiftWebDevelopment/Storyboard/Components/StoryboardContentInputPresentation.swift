import Foundation
import SwiftHTML
import SwiftWebUI

// Editorial content for the Selection & input and Presentation categories.

// MARK: - Variant helpers

/// A constant binding for static variant demos: reads return `value`, writes
/// are discarded. Variant cards render once and never update, so a live
/// source of truth would be dead weight here.
private func constant<Value: Sendable>(_ value: Value) -> Binding<Value> {
    Binding(get: { value }, set: { _ in })
}

/// A fixed instant (2026-06-15 09:30 UTC) so the DatePicker variants render
/// the same value on every visit.
private let variantDate = Date(timeIntervalSince1970: 1_781_515_800)

/// A small rounded swatch that paints one `Color`.
private func colorSwatch(_ color: Color) -> some HTML {
    Text("").as(.span)
        .frame(width: 22, height: 22)
        .background(color, in: .rect(cornerRadius: 7))
}

/// A pill-shaped chip used as horizontally scrolling content.
private func scrollChip(_ title: String) -> some HTML {
    Text(title).as(.span)
        .font(.footnote)
        .padding(.horizontal, 10)
        .padding(.vertical, 4)
        .background(Color.secondary.opacity(0.12), in: .capsule)
}

// MARK: - Discussion

func inputPresentationDiscussion(for id: String) -> [String]? {
    switch id {
    case "textfield":
        return [
            "TextField binds a single line of editable text to a String. It renders as a real <label> wrapping a native <input>, so clicking the label focuses the field and assistive technology reads the pair as one control. Trailing HTML attributes carry the web's input semantics: .type(.email), .url, or .search selects the browser's keyboard, validation, and autofill hints without changing the binding.",
            "The field composes the shared thin material, so its fill and backdrop blur track the active theme; <input> is a replaced element, so the material's rim and refraction overlay intentionally do not paint here. Every keystroke flows through the native input event into the binding, and textFieldStyle(_:) switches between the automatic, plain, and square-border recipes.",
        ]
    case "securefield":
        return [
            "SecureField is masked text entry for secrets. It shares TextField's anatomy — a visible label wrapping a native input on the thin material — but lowers to input[type=password], so the browser masks each glyph and offers its password-manager autofill. The value round-trips through the same String binding as TextField.",
            "A prompt renders as the placeholder, and because the control is TextField underneath, textFieldStyle(_:), controlSize(_:), and disabled(_:) all apply unchanged.",
        ]
    case "texteditor":
        return [
            "TextEditor binds multi-line text to a String and lowers to a native <textarea> — the web's real multi-line editor — rather than re-implementing selection, IME input, and undo. It composes the same thin material as TextField and reserves three control heights of room so short notes never start cramped.",
            "The server renders the bound value as the element's text content for a correct first paint, while the client patches it as a live property; both directions go through the same binding. textFieldStyle(.plain) strips the fill and border for seamless in-context editing.",
        ]
    case "form":
        return [
            "Form groups controls for data entry. Without an action it deliberately lowers to a plain <div>: a real <form> with no action would enable the browser's implicit submission, where pressing Enter in a text field issues a GET to the current URL — reloading the page and leaking field values into the query string. Buttons with server actions still work inside the presentational group; each wraps itself in its own dedicated <form>.",
            "With action: (and an optional method:), the container lowers to a real <form> that submits its named controls to that path with no client runtime required. SubmitButton provides the submit control and carries a primary or secondary prominence.",
        ]
    case "toggle":
        return [
            "Toggle binds a Bool to a switch. It lowers to a real checkbox input wrapped in a <label>, so activation, focus, keyboard toggling, and assistive-technology semantics are all native — the visible track and thumb are presentation layered over that input.",
            "The track composes the shared thin material for its fill and backdrop blur, and the thumb is a real Liquid Glass element rather than a pseudo-element, so the per-element refraction script can target it: the thumb refracts the track and backdrop through its rim. toggleStyle(.checkbox) squares the control into a checkbox look.",
        ]
    case "slider":
        return [
            "Slider binds a Double within a closed range, with an optional step. A transparent native range input on top owns every interaction — drag, keyboard arrows, stepping, focus, and accessibility — so value commits come from the input's trusted events rather than synthesized pointer math.",
            "The visible track, fill, and Liquid Glass thumb are drawn beneath the input and positioned from a CSS custom property: the client updates it live on every input event, and the server seeds it inline so the first paint is already correct. onEditingChanged fires exactly once per drag — true on the first input event, false on the native change event a range input emits on release.",
        ]
    case "stepper":
        return [
            "Stepper increments or decrements a bound Int by a fixed step, clamped to optional bounds. Like SwiftUI's, it renders its title and the two buttons but not the value — interpolate the value into the title to display it.",
            "It lowers to a role=\"group\" of two native buttons. Each button disables itself when the next step would leave the bounds, so the edge states are visible without extra wiring, and the onIncrement/onDecrement overload supports custom stepping without a binding.",
        ]
    case "picker":
        return [
            "Picker binds a String selection to a list of PickerOptions, and pickerStyle(_:) chooses the presentation without touching the binding: automatic and menu lower to a native <select>, while segmented and inline lower to a role=\"radiogroup\" of real radio inputs — segmented composing the shared bar material, inline as a plain vertical list.",
            "Only styles with an honest native control are exposed: the web has no wheel or palette equivalent, so those SwiftUI cases are intentionally omitted rather than silently degraded. In the radio-group styles one delegated change handler on the group container drives the whole group, and the group name derives from the label — give two pickers on one page distinct labels.",
        ]
    case "datepicker":
        return [
            "DatePicker binds a Date, and displayedComponents picks the native control: .date lowers to input[type=date], .hourAndMinute to time, and both together to datetime-local — the calendar and clock UI are the browser's own.",
            "The bound Date stays an absolute instant; the rendered value and the parsed input both use the runtime's Calendar.current, the same explicit choice SwiftUI makes through its environment calendar. Clearing the field or typing an unparseable value keeps the prior date, because Binding<Date> cannot represent an empty selection.",
        ]
    case "colorpicker":
        return [
            "ColorPicker binds a color selection to a native color well — input[type=color] — so the swatch, eyedropper, and picker popover are the platform's own. The selection is a #rrggbb hex string, the exact value format the native input speaks; the API deliberately binds that string instead of inventing a lossy Color round-trip.",
            "supportsOpacity is accepted for canonical call-site compatibility, but the native color input cannot represent an alpha component yet, so selections are always fully opaque; the flag will be wired through once browsers support alpha in the native control.",
        ]
    case "color":
        return [
            "Color is the framework's single concrete color type: hex and RGB/HSB literals, the standard palette, and the semantic colors are all Color, so they compose without type erasure. Palette colors adapt between light and dark through CSS light-dark(), semantic colors resolve to root custom properties so .accent and .surface always track the active theme, and opacity(_:) and mix(with:by:) lower to CSS color-mix while staying scheme-adaptive.",
            "tint(_:) writes the environment tint that controls read — it recolors one control's accent (button fill, slider track, stepper buttons) without touching the global color scheme, mirroring SwiftUI's separation between the app accent color and per-view tint.",
        ]
    case "alert":
        return [
            "alert(_:isPresented:actions:message:) interrupts with a modal decision the user must resolve. It lowers to a native <dialog> rendered as a sibling of its anchor and costs no layout while hidden; when the binding turns true the server renders the dialog open and the client runtime lifts it to a true top-layer modal via showModal(). Native dismissal — Esc or a backdrop tap — fires the dialog's close event, which writes the binding back to false, so state and screen cannot silently drift apart.",
            "confirmationDialog(_:isPresented:titleVisibility:actions:) shares the same engine with SwiftUI's title rules: automatic hides the title without a message and shows it with one. interactiveDismissDisabled() forces the dialog's light-dismiss policy to none, so only an explicit action can close it. Without the client runtime the dialog still presents as an in-flow modal panel driven by the binding — degradation is explicit, not silent. Because presentation lives in that live Bool binding, this page has no static variants; the playground below drives the real dialog.",
        ]
    case "sheet":
        return [
            "sheet(isPresented:onDismiss:content:) lifts arbitrary content into a panel above the current context. It shares the alert's engine: a native <dialog> sibling of the anchor, composed on the thick material, raised to the browser top layer by the client runtime, and dismissed natively by Esc or a backdrop tap. The dialog's close event writes the binding back to false and then runs onDismiss.",
            "popover(isPresented:content:) reuses the same machinery for lighter, source-adjacent presentations, and interactiveDismissDisabled() opts a presentation out of light dismissal so only explicit controls can close it — the runtime then never binds its backdrop handler. Because presentation lives in a live Bool binding, this page has no static variants; the playground below presents the real sheet.",
        ]
    case "scrollview":
        return [
            "ScrollView clips overflow and scrolls along its axes: each axis in the set lowers to overflow auto while the off-axis is hidden, so content can never leak out sideways. Overscroll is contained, which keeps a nested scroll from chaining into the page behind it.",
            "Like SwiftUI's, it needs a bounded frame from outside to have something to scroll within — give it a frame or let a parent constrain it, and the content determines how far it scrolls. showsIndicators: false hides the scrollbars on every engine while leaving wheel, drag, and keyboard scrolling untouched.",
        ]
    default:
        return nil
    }
}

// MARK: - SwiftUI parity

func inputPresentationParity(for id: String) -> String? {
    switch id {
    case "textfield":
        return "Same shape as SwiftUI's TextField(_:text:prompt:); the trailing HTML attributes such as .type(.email) are the sanctioned web extension for input semantics."
    case "securefield":
        return "Same shape as SwiftUI's SecureField(_:text:prompt:); the password input type is what invites the browser's password-manager autofill."
    case "texteditor":
        return "Same shape as SwiftUI's TextEditor(text:); it lowers to a native <textarea> instead of a custom editing surface."
    case "form":
        return "Same shape as SwiftUI's Form { }; the action:method: overload is the web extension that lowers to a native <form> submission."
    case "toggle":
        return "Same shape as SwiftUI's Toggle(_:isOn:), including toggleStyle(_:)."
    case "slider":
        return "Same shape as SwiftUI's Slider(value:in:step:onEditingChanged:)."
    case "stepper":
        return "Same shape as SwiftUI's Stepper(_:value:in:step:onEditingChanged:), including the onIncrement/onDecrement overload."
    case "picker":
        return "Same shape as SwiftUI's Picker(_:selection:content:) with pickerStyle(_:); the wheel and palette styles are intentionally absent on the web."
    case "datepicker":
        return "Same shape as SwiftUI's DatePicker(_:selection:displayedComponents:); the presentation is the browser's native control rather than datePickerStyle variants."
    case "colorpicker":
        return "Same shape as SwiftUI's ColorPicker(_:selection:supportsOpacity:), with the selection bound as the hex string the native control uses."
    case "color":
        return "Same shape as SwiftUI's Color and tint(_:): the standard palette, semantic colors, and opacity(_:)/mix(with:by:) all return Color."
    case "alert":
        return "Same shape as SwiftUI's alert(_:isPresented:actions:message:) and confirmationDialog(_:isPresented:titleVisibility:actions:); presentation state lives in the Bool binding."
    case "sheet":
        return "Same shape as SwiftUI's sheet(isPresented:onDismiss:content:) and popover(isPresented:content:)."
    case "scrollview":
        return "Same shape as SwiftUI's ScrollView(_:showsIndicators:content:)."
    default:
        return nil
    }
}

// MARK: - Variants

func inputPresentationVariants(for id: String) -> [CatalogVariant]? {
    switch id {
    case "textfield":
        return textFieldVariants()
    case "securefield":
        return secureFieldVariants()
    case "texteditor":
        return textEditorVariants()
    case "form":
        return formVariants()
    case "toggle":
        return toggleVariants()
    case "slider":
        return sliderVariants()
    case "stepper":
        return stepperVariants()
    case "picker":
        return pickerVariants()
    case "datepicker":
        return datePickerVariants()
    case "colorpicker":
        return colorPickerVariants()
    case "color":
        return colorVariants()
    case "scrollview":
        return scrollViewVariants()
    default:
        // alert and sheet have no static variants: presentation requires a
        // live isPresented binding, which the playground below provides.
        return nil
    }
}

private func textFieldVariants() -> [CatalogVariant] {
    [
        CatalogVariant("Default", detail: "The automatic style on the thin material; the prompt renders as the placeholder.") {
            TextField("Name", text: constant(""), prompt: Text("Jane Appleseed"))
                .frame(width: 180)
        },
        CatalogVariant(".plain", detail: "No fill, border, or shadow; the field disappears into its context.") {
            TextField("Name", text: constant("Jane Appleseed"))
                .textFieldStyle(.plain)
                .frame(width: 180)
        },
        CatalogVariant(".squareBorder", detail: "The automatic recipe with square corners.") {
            TextField("Name", text: constant("Jane Appleseed"))
                .textFieldStyle(.squareBorder)
                .frame(width: 180)
        },
        CatalogVariant("Input type hint", detail: ".type(.email) selects the browser's keyboard, validation, and autofill.") {
            TextField("Email", text: constant(""), prompt: Text("you@example.com"), .type(.email))
                .frame(width: 180)
        },
        CatalogVariant("Control sizes", detail: ".controlSize(_:) scales the field's height and type together.") {
            VStack(alignment: .leading, spacing: .small) {
                TextField("Small", text: constant(""), prompt: Text("Small"))
                    .controlSize(.small)
                    .frame(width: 180)
                TextField("Large", text: constant(""), prompt: Text("Large"))
                    .controlSize(.large)
                    .frame(width: 180)
            }
        },
        CatalogVariant("Disabled", detail: ".disabled(true) dims the field and blocks input natively.") {
            TextField("Name", text: constant("Jane Appleseed"))
                .disabled(true)
                .frame(width: 180)
        },
    ]
}

private func secureFieldVariants() -> [CatalogVariant] {
    [
        CatalogVariant("Filled", detail: "The browser masks each glyph of the bound value.") {
            SecureField("Password", text: constant("correct horse"))
                .frame(width: 180)
        },
        CatalogVariant("Empty with prompt", detail: "The prompt renders as the placeholder until entry begins.") {
            SecureField("Password", text: constant(""), prompt: Text("Required"))
                .frame(width: 180)
        },
        CatalogVariant(".plain", detail: "textFieldStyle applies unchanged; the field is TextField underneath.") {
            SecureField("Password", text: constant("correct horse"))
                .textFieldStyle(.plain)
                .frame(width: 180)
        },
        CatalogVariant("Disabled", detail: ".disabled(true) dims the field and blocks input natively.") {
            SecureField("Password", text: constant("correct horse"))
                .disabled(true)
                .frame(width: 180)
        },
    ]
}

private func textEditorVariants() -> [CatalogVariant] {
    [
        CatalogVariant("Default", detail: "A native textarea on the thin material with three control heights of room.") {
            TextEditor(text: constant("Meeting notes.\nFollow up on the design review."))
                .frame(width: 180)
        },
        CatalogVariant(".plain", detail: "Strips the fill and border for seamless in-context editing.") {
            TextEditor(text: constant("Meeting notes.\nFollow up on the design review."))
                .textFieldStyle(.plain)
                .frame(width: 180)
        },
        CatalogVariant("Disabled", detail: ".disabled(true) dims the editor and blocks input natively.") {
            TextEditor(text: constant("Read-only draft."))
                .disabled(true)
                .frame(width: 180)
        },
    ]
}

private func formVariants() -> [CatalogVariant] {
    [
        CatalogVariant("Presentational group", detail: "No action: lowers to a <div>, so Enter cannot trigger implicit submission.") {
            Form {
                VStack(alignment: .leading, spacing: .small) {
                    Label("Email address", systemImage: "envelope")
                    TextField("Email", text: constant(""), prompt: Text("you@example.com"))
                        .frame(width: 180)
                }
            }
        },
        CatalogVariant("Submitting form", detail: "action: lowers to a real <form> that posts its named controls to the path.") {
            Form(action: "/subscribe", method: .post) {
                VStack(alignment: .leading, spacing: .small) {
                    TextField("Email", text: constant(""), prompt: Text("you@example.com"))
                        .frame(width: 180)
                    SubmitButton("Subscribe", prominence: .primary)
                }
            }
        },
        CatalogVariant("SubmitButton prominence", detail: "One primary submit per form; secondary for the alternatives.") {
            Form(action: "/drafts", method: .post) {
                HStack(spacing: .small) {
                    SubmitButton("Save", prominence: .primary)
                    SubmitButton("Save draft")
                }
            }
        },
    ]
}

private func toggleVariants() -> [CatalogVariant] {
    [
        CatalogVariant("Off", detail: "The thumb rests at the leading edge of the material track.") {
            Toggle("Wi-Fi", isOn: constant(false))
        },
        CatalogVariant("On", detail: "The track fills with the accent; the glass thumb refracts it.") {
            Toggle("Wi-Fi", isOn: constant(true))
        },
        CatalogVariant(".checkbox", detail: "toggleStyle(.checkbox) squares the control into a checkbox look.") {
            Toggle("Accept terms", isOn: constant(true))
                .toggleStyle(.checkbox)
        },
        CatalogVariant("Control sizes", detail: ".controlSize(_:) scales the track and thumb together.") {
            VStack(alignment: .leading, spacing: .xsmall) {
                Toggle("Small", isOn: constant(true)).controlSize(.small)
                Toggle("Regular", isOn: constant(true))
                Toggle("Large", isOn: constant(true)).controlSize(.large)
            }
        },
        CatalogVariant("Disabled", detail: ".disabled(true) dims the switch and blocks toggling natively.") {
            Toggle("Wi-Fi", isOn: constant(true))
                .disabled(true)
        },
    ]
}

private func sliderVariants() -> [CatalogVariant] {
    [
        CatalogVariant("Value positions", detail: "The fill and thumb track the bound value across the range.") {
            VStack(spacing: .small) {
                Slider(value: constant(0)).frame(width: 180)
                Slider(value: constant(0.5)).frame(width: 180)
                Slider(value: constant(1)).frame(width: 180)
            }
        },
        CatalogVariant("Stepped", detail: "step: 0.25 snaps drags and arrow keys to quarter increments.") {
            Slider(value: constant(0.75), in: 0...1, step: 0.25)
                .frame(width: 180)
        },
        CatalogVariant("Tinted", detail: ".tint(_:) recolors the fill without changing the scheme.") {
            Slider(value: constant(0.4))
                .tint(.green)
                .frame(width: 180)
        },
        CatalogVariant("Disabled", detail: ".disabled(true) dims the control and disables the native input.") {
            Slider(value: constant(0.5))
                .disabled(true)
                .frame(width: 180)
        },
    ]
}

private func stepperVariants() -> [CatalogVariant] {
    [
        CatalogVariant("Mid-range", detail: "Both buttons active; the title carries the interpolated value.") {
            Stepper("Value: 4", value: constant(4), in: 0...8)
        },
        CatalogVariant("At lower bound", detail: "Decrement disables itself when the next step would leave the bounds.") {
            Stepper("Value: 0", value: constant(0), in: 0...8)
        },
        CatalogVariant("At upper bound", detail: "Increment disables itself at the top of the range.") {
            Stepper("Value: 8", value: constant(8), in: 0...8)
        },
        CatalogVariant("Tinted", detail: ".tint(_:) recolors the buttons without changing the scheme.") {
            Stepper("Value: 4", value: constant(4), in: 0...8)
                .tint(.purple)
        },
        CatalogVariant("Disabled", detail: ".disabled(true) disables both buttons regardless of bounds.") {
            Stepper("Value: 4", value: constant(4), in: 0...8)
                .disabled(true)
        },
    ]
}

private func pickerVariants() -> [CatalogVariant] {
    [
        CatalogVariant(".menu", detail: "A pop-up menu lowered to a native <select>; the automatic default.") {
            Picker("View", selection: constant("grid")) {
                PickerOption("List", value: "list")
                PickerOption("Grid", value: "grid")
                PickerOption("Columns", value: "columns")
            }
            .pickerStyle(.menu)
            .frame(width: 180)
        },
        CatalogVariant(".segmented", detail: "A radiogroup of native radios composing the bar material.") {
            Picker("Layout", selection: constant("grid")) {
                PickerOption("List", value: "list")
                PickerOption("Grid", value: "grid")
                PickerOption("Columns", value: "columns")
            }
            .pickerStyle(.segmented)
            .frame(width: 200)
        },
        CatalogVariant(".inline", detail: "A vertical radiogroup with no surrounding chrome.") {
            Picker("Sort by", selection: constant("date")) {
                PickerOption("Date", value: "date")
                PickerOption("Name", value: "name")
                PickerOption("Size", value: "size")
            }
            .pickerStyle(.inline)
        },
        CatalogVariant("Disabled", detail: ".disabled(true) disables the native select and dims the field.") {
            Picker("View", selection: constant("grid")) {
                PickerOption("List", value: "list")
                PickerOption("Grid", value: "grid")
                PickerOption("Columns", value: "columns")
            }
            .pickerStyle(.menu)
            .disabled(true)
            .frame(width: 180)
        },
    ]
}

private func datePickerVariants() -> [CatalogVariant] {
    [
        CatalogVariant("Date only", detail: "[.date] lowers to input[type=date] with the browser's calendar.") {
            DatePicker("Due date", selection: constant(variantDate), displayedComponents: [.date])
        },
        CatalogVariant("Time only", detail: "[.hourAndMinute] lowers to input[type=time].") {
            DatePicker("Reminder", selection: constant(variantDate), displayedComponents: [.hourAndMinute])
        },
        CatalogVariant("Date and time", detail: "Both components lower to input[type=datetime-local].") {
            DatePicker("Event", selection: constant(variantDate), displayedComponents: [.date, .hourAndMinute])
        },
        CatalogVariant("Disabled", detail: ".disabled(true) dims the field and blocks the native picker.") {
            DatePicker("Due date", selection: constant(variantDate), displayedComponents: [.date])
                .disabled(true)
        },
    ]
}

private func colorPickerVariants() -> [CatalogVariant] {
    [
        CatalogVariant("Accent hue", detail: "The native color well shows the bound #rrggbb value.") {
            ColorPicker("Accent", selection: constant("#5856d6"))
        },
        CatalogVariant("Warm hue", detail: "Any hex string seeds the well; edits round-trip the same format.") {
            ColorPicker("Highlight", selection: constant("#ff9500"))
        },
        CatalogVariant("Disabled", detail: ".disabled(true) blocks the native picker popover.") {
            ColorPicker("Accent", selection: constant("#5856d6"))
                .disabled(true)
        },
    ]
}

private func colorVariants() -> [CatalogVariant] {
    [
        CatalogVariant("Standard palette", detail: "The system palette, adapting light and dark via light-dark().") {
            HStack(spacing: .xsmall) {
                colorSwatch(.red)
                colorSwatch(.orange)
                colorSwatch(.yellow)
                colorSwatch(.green)
                colorSwatch(.blue)
                colorSwatch(.indigo)
                colorSwatch(.purple)
            }
        },
        CatalogVariant("Semantic colors", detail: ".accent, .danger, .surfaceRaised, and .border resolve to theme tokens.") {
            HStack(spacing: .small) {
                colorSwatch(.accent)
                colorSwatch(.danger)
                colorSwatch(.surfaceRaised)
                colorSwatch(.border)
            }
        },
        CatalogVariant("Opacity", detail: ".opacity(_:) lowers to color-mix and stays scheme-adaptive.") {
            HStack(spacing: .small) {
                colorSwatch(.accent)
                colorSwatch(Color.accent.opacity(0.55))
                colorSwatch(Color.accent.opacity(0.25))
            }
        },
        CatalogVariant("Mix", detail: ".mix(with:by:) blends two colors in sRGB.") {
            HStack(spacing: .small) {
                colorSwatch(.blue)
                colorSwatch(Color.blue.mix(with: .pink, by: 0.5))
                colorSwatch(.pink)
            }
        },
        CatalogVariant("Tinted controls", detail: ".tint(_:) recolors one control's accent, not the scheme.") {
            VStack(alignment: .leading, spacing: .small) {
                Button("Save") {}.buttonStyle(.borderedProminent).tint(.green)
                Slider(value: constant(0.6))
                    .tint(.purple)
                    .frame(width: 170)
            }
        },
    ]
}

private func scrollViewVariants() -> [CatalogVariant] {
    [
        CatalogVariant("Vertical", detail: "Content taller than the frame scrolls on the y axis; x stays clipped.") {
            ScrollView(.vertical) {
                VStack(alignment: .leading, spacing: .xsmall) {
                    ForEach(["Inbox", "Drafts", "Sent", "Archive", "Junk", "Trash"], id: { $0 }) { name in
                        Text(name).font(.footnote)
                    }
                }
            }
            .frame(width: 170, height: 84)
        },
        CatalogVariant("Horizontal", detail: "ScrollView(.horizontal) scrolls a row wider than its frame.") {
            ScrollView(.horizontal) {
                HStack(spacing: .small) {
                    ForEach(["Today", "This week", "This month", "This year", "All time"], id: { $0 }) { name in
                        scrollChip(name)
                    }
                }
            }
            .frame(width: 170)
        },
        CatalogVariant("Hidden indicators", detail: "showsIndicators: false hides the scrollbars; scrolling still works.") {
            ScrollView(.vertical, showsIndicators: false) {
                VStack(alignment: .leading, spacing: .xsmall) {
                    ForEach(["Inbox", "Drafts", "Sent", "Archive", "Junk", "Trash"], id: { $0 }) { name in
                        Text(name).font(.footnote)
                    }
                }
            }
            .frame(width: 170, height: 84)
        },
    ]
}
