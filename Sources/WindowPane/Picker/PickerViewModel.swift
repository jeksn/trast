import Foundation
import KeyboardShortcuts
import WindowPaneCore

enum PickerItem: Identifiable {
    case command(WindowCommand, hotkeyName: KeyboardShortcuts.Name)
    case appShortcut(AppShortcut, hotkeyName: KeyboardShortcuts.Name)

    var id: String { hotkeyName.rawValue }

    var title: String {
        switch self {
        case .command(let command, _):
            return command.name
        case .appShortcut(let shortcut, _):
            return shortcut.name
        }
    }

    var hotkeyName: KeyboardShortcuts.Name {
        switch self {
        case .command(_, let name), .appShortcut(_, let name):
            return name
        }
    }

    var icon: String {
        switch self {
        case .command:
            return "macwindow"
        case .appShortcut(let shortcut, _):
            switch shortcut.kind {
            case .app: return "arrow.right.square"
            case .url: return "link"
            case .folder: return "folder"
            }
        }
    }

    var section: String {
        switch self {
        case .command(_, let name):
            return name.rawValue.hasPrefix("action.") ? "Actions" : "Commands"
        case .appShortcut:
            return "Shortcuts"
        }
    }
}

struct PickerSection: Identifiable {
    let title: String
    let items: [PickerItem]
    var id: String { title }
}

final class PickerViewModel: ObservableObject {
    @Published var query = "" {
        didSet { selectedIndex = 0 }
    }
    @Published var selectedIndex = 0
    @Published var focusToken = UUID()

    var items: [PickerItem] = []

    func reset() {
        query = ""
        selectedIndex = 0
        focusToken = UUID()
    }

    var filtered: [PickerItem] {
        FuzzyMatch.ranked(items, query: query) { $0.title }
    }

    var sections: [PickerSection] {
        let filtered = self.filtered
        return ["Commands", "Actions", "Shortcuts"].compactMap { title in
            let sectionItems = filtered.filter { $0.section == title }
            return sectionItems.isEmpty ? nil : PickerSection(title: title, items: sectionItems)
        }
    }

    func moveSelection(_ delta: Int) {
        let count = filtered.count
        guard count > 0 else { return }
        selectedIndex = (selectedIndex + delta + count) % count
    }

    func selectedItem() -> PickerItem? {
        filtered[safe: selectedIndex]
    }
}
