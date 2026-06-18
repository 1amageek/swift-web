import SwiftHTML

public struct ThemeSwitcher: ClientComponent {
    private let themes: [Theme]
    private let selection: Binding<Theme>

    public init(selection: Binding<Theme>, themes: [Theme]) {
        self.selection = selection
        self.themes = themes
    }

    @HTMLBuilder
    public var body: some HTML {
        HStack(spacing: .small) {
            ForEach(themes, id: \.name) { theme in
                let isSelected = selection.wrappedValue == theme
                Button(theme.name) {
                    selection.wrappedValue = theme
                }
                    .data("theme-option", theme.name)
                    .data("theme-selected", isSelected ? "true" : "false")
                    .accessibilityRole("switch")
                    .accessibilityValue(isSelected ? "on" : "off")
            }
        }
    }
}
