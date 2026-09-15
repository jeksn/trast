import SwiftUI

struct SettingsView: View {
    var body: some View {
        TabView {
            CommandListView()
                .tabItem { Label("Commands", systemImage: "rectangle.split.2x2") }
            AppShortcutListView()
                .tabItem { Label("Shortcuts", systemImage: "arrow.right.square") }
            SnippetListView()
                .tabItem { Label("Snippets", systemImage: "text.append") }
            ClipboardSettingsView()
                .tabItem { Label("Clipboard", systemImage: "clipboard") }
            GeneralSettingsView()
                .tabItem { Label("General", systemImage: "gearshape") }
        }
        .frame(width: 780, height: 560)
    }
}
