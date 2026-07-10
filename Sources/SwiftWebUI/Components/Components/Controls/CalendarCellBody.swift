import SwiftHTML

/// The free-form area below a day number in a ``CalendarView`` cell. Place
/// event dots, availability markers, or any other per-day content here; it
/// renders inside ``CalendarCellContent`` after the ``CalendarCellHeader``.
public struct CalendarCellBody<Content: HTML>: Component {
    private let content: Content

    public init(@HTMLBuilder content: () -> Content) {
        self.content = content()
    }

    public var body: some HTML {
        div(.class("swui-calendar-cell-body"), .data("slot", "cell-body")) {
            content
        }
    }
}
