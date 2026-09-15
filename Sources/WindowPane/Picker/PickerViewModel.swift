import Foundation
import KeyboardShortcuts
import WindowPaneCore
import AppKit

enum PickerAction: String, CaseIterable, Identifiable {
    case settings
    case clipboardHistory
    case checkForUpdates
    case quit

    var id: String { rawValue }

    var title: String {
        switch self {
        case .settings: return "Settings"
        case .clipboardHistory: return "Clipboard History"
        case .checkForUpdates: return "Check for Updates"
        case .quit: return "Quit WindowPane"
        }
    }

    var icon: String {
        switch self {
        case .settings: return "gearshape"
        case .clipboardHistory: return "clipboard"
        case .checkForUpdates: return "arrow.triangle.2.circlecircle"
        case .quit: return "power"
        }
    }
}

enum PickerItem: Identifiable {
    case command(WindowCommand, hotkeyName: KeyboardShortcuts.Name)
    case appShortcut(AppShortcut, hotkeyName: KeyboardShortcuts.Name)
    case installedApp(AppChooserItem, hotkeyName: KeyboardShortcuts.Name)
    case pickerAction(PickerAction)

    var id: String {
        switch self {
        case .command(_, let name), .appShortcut(_, let name), .installedApp(_, let name):
            return name.rawValue
        case .pickerAction(let action):
            return "pickerAction.\(action.rawValue)"
        }
    }

    var title: String {
        switch self {
        case .command(let command, _):
            return command.name
        case .appShortcut(let shortcut, _):
            return shortcut.name
        case .installedApp(let app, _):
            return app.name
        case .pickerAction(let action):
            return action.title
        }
    }

    var hotkeyName: KeyboardShortcuts.Name? {
        switch self {
        case .command(_, let name), .appShortcut(_, let name), .installedApp(_, let name):
            return name
        case .pickerAction:
            return nil
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
        case .installedApp:
            return "app"
        case .pickerAction(let action):
            return action.icon
        }
    }

    var iconImage: NSImage? {
        switch self {
        case .installedApp(let app, _):
            return app.icon
        case .command, .appShortcut, .pickerAction:
            return nil
        }
    }

    var section: String {
        switch self {
        case .command(_, let name):
            return name.rawValue.hasPrefix("action.") ? "Actions" : "Commands"
        case .appShortcut:
            return "Shortcuts"
        case .installedApp:
            return "Applications"
        case .pickerAction:
            return "WindowPane"
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
        let trimmed = query.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return [] }
        return FuzzyMatch.ranked(items, query: query) { $0.title }
    }

    var sections: [PickerSection] {
        let filtered = self.filtered
        return ["Commands", "Actions", "Shortcuts", "Applications", "WindowPane"].compactMap { title in
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
