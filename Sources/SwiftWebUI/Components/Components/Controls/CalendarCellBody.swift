import SwiftHTML

/// The free-form area below a day number in a ``CalendarView`` cell. Place
/// event dots, availability markers, or any other per-day content here; it
/// renders inside ``CalendarCellContent`` after the ``CalendarCellHeader``.
public struct CalendarCellBody<Content: Component>: Component {
    private let childContent: Content

    public init(@HTMLBuilder content: () -> Content) {
        self.childContent = content()
    }

    public var content: some Component {
        div(.class("swui-calendar-cell-body"), .data("slot", "cell-body")) {
            childContent
        }
    }
}
