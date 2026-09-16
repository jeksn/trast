import Foundation
import KeyboardShortcuts
import WindowPaneCore
import AppKit

enum LauncherAction: String, CaseIterable, Identifiable {
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

enum LauncherItem: Identifiable {
    case command(WindowCommand, hotkeyName: KeyboardShortcuts.Name)
    case appShortcut(AppShortcut, hotkeyName: KeyboardShortcuts.Name)
    case installedApp(AppChooserItem, hotkeyName: KeyboardShortcuts.Name)
    case launcherAction(LauncherAction)

    var id: String {
        switch self {
        case .command(_, let name), .appShortcut(_, let name), .installedApp(_, let name):
            return name.rawValue
        case .launcherAction(let action):
            return "launcherAction.\(action.rawValue)"
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
        case .launcherAction(let action):
            return action.title
        }
    }

    var hotkeyName: KeyboardShortcuts.Name? {
        switch self {
        case .command(_, let name), .appShortcut(_, let name), .installedApp(_, let name):
            return name
        case .launcherAction:
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
        case .launcherAction(let action):
            return action.icon
        }
    }

    var iconImage: NSImage? {
        switch self {
        case .installedApp(let app, _):
            return app.icon
        case .command, .appShortcut, .launcherAction:
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
        case .launcherAction:
            return "WindowPane"
        }
    }
}

struct LauncherSection: Identifiable {
    let title: String
    let items: [LauncherItem]
    var id: String { title }
}

final class LauncherViewModel: ObservableObject {
    enum Category: String, CaseIterable, Hashable {
        case all
        case commands
        case shortcuts
        case applications
        case clipboard
        case windowPane

        var label: String {
            switch self {
            case .all: return "All"
            case .commands: return "Commands"
            case .shortcuts: return "Shortcuts"
            case .applications: return "Apps"
            case .clipboard: return "Clipboard"
            case .windowPane: return "WindowPane"
            }
        }

        var icon: String {
            switch self {
            case .all: return "magnifyingglass"
            case .commands: return "macwindow"
            case .shortcuts: return "arrow.right.square"
            case .applications: return "app"
            case .clipboard: return "clipboard"
            case .windowPane: return "gearshape"
            }
        }
    }

    private static let placeholders = [
        "What do you want to do?",
        "Search commands, apps, and more...",
        "Type to search...",
        "What's next?",
        "Search everything...",
        "What are you looking for?",
    ]

    @Published var placeholder: String = placeholders[0]
    @Published var selectedCategory: Category = .all
    @Published var query = "" {
        didSet { selectedIndex = 0 }
    }
    @Published var selectedIndex = 0
    @Published var focusToken = UUID()

    var items: [LauncherItem] = []

    func reset() {
        placeholder = Self.placeholders.randomElement() ?? Self.placeholders[0]
        selectedCategory = .all
        query = ""
        selectedIndex = 0
        focusToken = UUID()
    }

    var filtered: [LauncherItem] {
        let trimmed = query.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return [] }
        let ranked = FuzzyMatch.ranked(items, query: query) { $0.title }
        switch selectedCategory {
        case .all:
            return ranked
        case .commands:
            return ranked.filter { $0.section == "Commands" || $0.section == "Actions" }
        case .shortcuts:
            return ranked.filter { $0.section == "Shortcuts" }
        case .applications:
            return ranked.filter { $0.section == "Applications" }
        case .clipboard:
            return ranked.filter { $0.section == "WindowPane" && $0.title == "Clipboard History" }
        case .windowPane:
            return ranked.filter { $0.section == "WindowPane" }
        }
    }

    func cycleCategory() {
        let allCases = Category.allCases
        guard let currentIndex = allCases.firstIndex(of: selectedCategory) else { return }
        selectedCategory = allCases[(currentIndex + 1) % allCases.count]
        selectedIndex = 0
    }

    func cycleCategoryBackward() {
        let allCases = Category.allCases
        guard let currentIndex = allCases.firstIndex(of: selectedCategory) else { return }
        let count = allCases.count
        selectedCategory = allCases[(currentIndex - 1 + count) % count]
        selectedIndex = 0
    }

    func selectCategory(_ category: Category) {
        selectedCategory = category
        selectedIndex = 0
    }

    var sections: [LauncherSection] {
        let filtered = self.filtered
        return ["Commands", "Actions", "Shortcuts", "Applications", "WindowPane"].compactMap { title in
            let sectionItems = filtered.filter { $0.section == title }
            return sectionItems.isEmpty ? nil : LauncherSection(title: title, items: sectionItems)
        }
    }

    func moveSelection(_ delta: Int) {
        let count = filtered.count
        guard count > 0 else { return }
        selectedIndex = (selectedIndex + delta + count) % count
    }

    func selectedItem() -> LauncherItem? {
        filtered[safe: selectedIndex]
    }
}
