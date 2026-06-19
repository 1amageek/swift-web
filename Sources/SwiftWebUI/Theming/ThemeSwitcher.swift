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
        Picker("Appearance", selection: themeName) {
            ForEach(themes, id: \.name) { theme in
                PickerOption(theme.name, value: theme.name, .data("theme-option", theme.name))
            }
        }
        .pickerStyle(.segmented)
    }

    private var themeName: Binding<String> {
        Binding<String>(
            get: {
                selection.wrappedValue.name
            },
            set: { name in
                guard let theme = themes.first(where: { $0.name == name }) else {
                    return
                }
                selection.wrappedValue = theme
            }
        )
    }
}
