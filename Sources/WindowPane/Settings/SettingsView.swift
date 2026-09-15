import SwiftUI
import WindowPaneCore

struct SettingsView: View {
    @State private var selection: SettingsSection = .general

    var body: some View {
        NavigationSplitView {
            List(selection: $selection) {
                Section {
                    ForEach(SettingsSection.allCases) { section in
                        Label(section.title, systemImage: section.icon)
                            .tag(section)
                    }
                }
            }
            .listStyle(.sidebar)
            .navigationSplitViewColumnWidth(min: 200, ideal: 220, max: 260)
            .navigationTitle("WindowPane")
        } detail: {
            switch selection {
            case .general:
                GeneralSettingsView()
            case .commands:
                CommandListView()
            case .shortcuts:
                AppShortcutListView()
            case .snippets:
                SnippetListView()
            case .clipboard:
                ClipboardSettingsView()
            }
        }
    }
}

enum SettingsSection: String, CaseIterable, Identifiable, Hashable {
    case general
    case commands
    case shortcuts
    case snippets
    case clipboard

    var id: String { rawValue }

    var title: String {
        switch self {
        case .general: return "General"
        case .commands: return "Commands"
        case .shortcuts: return "Shortcuts"
        case .snippets: return "Snippets"
        case .clipboard: return "Clipboard"
        }
    }

    var icon: String {
        switch self {
        case .general: return "gearshape"
        case .commands: return "rectangle.split.2x2"
        case .shortcuts: return "arrow.right.square"
        case .snippets: return "text.append"
        case .clipboard: return "clipboard"
        }
    }
}
