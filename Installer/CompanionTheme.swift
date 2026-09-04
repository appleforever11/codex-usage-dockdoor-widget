import SwiftUI

struct CompanionThemeSurface: View {
    @AppStorage(CodexTheme.storageKey) private var selection = CodexTheme.astra.rawValue
    var body: some View {
        CodexThemeBackground(theme: CodexTheme(rawValue: selection) ?? .astra)
            .environment(\.colorScheme, .dark)
    }
}

struct CompanionThemePicker: View {
    @AppStorage(CodexTheme.storageKey) private var selection = CodexTheme.astra.rawValue
    var body: some View {
        CodexThemeMenu(selection: $selection)
            .environment(\.colorScheme, .dark)
    }
}
