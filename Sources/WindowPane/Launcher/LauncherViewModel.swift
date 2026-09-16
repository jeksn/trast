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

    static var windowPaneActions: [LauncherAction] {
        allCases.filter { $0 != .clipboardHistory }
    }
}

enum LauncherItem: Identifiable {
    case command(WindowCommand, hotkeyName: KeyboardShortcuts.Name)
    case appShortcut(AppShortcut, hotkeyName: KeyboardShortcuts.Name)
    case installedApp(AppChooserItem, hotkeyName: KeyboardShortcuts.Name)
    case launcherAction(LauncherAction)
    case clipboardEntry(ClipboardItem)
    case snippetEntry(Snippet)

    var id: String {
        switch self {
        case .command(_, let name), .appShortcut(_, let name), .installedApp(_, let name):
            return name.rawValue
        case .launcherAction(let action):
            return "launcherAction.\(action.rawValue)"
        case .clipboardEntry(let item):
            return "clipboard.\(item.id.uuidString)"
        case .snippetEntry(let snippet):
            return "snippet.\(snippet.id.uuidString)"
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
        case .clipboardEntry(let item):
            return item.displayName
        case .snippetEntry(let snippet):
            return snippet.name
        }
    }

    var hotkeyName: KeyboardShortcuts.Name? {
        switch self {
        case .command(_, let name), .appShortcut(_, let name), .installedApp(_, let name):
            return name
        case .launcherAction, .clipboardEntry, .snippetEntry:
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
        case .clipboardEntry(let item):
            switch item.kind {
            case .text: return "text.alignleft"
            case .image: return "photo"
            case .fileURL: return "doc"
            }
        case .snippetEntry:
            return "text.append"
        }
    }

    var iconImage: NSImage? {
        switch self {
        case .installedApp(let app, _):
            return app.icon
        case .clipboardEntry(let item):
            guard item.kind == .image, let data = item.imageData else { return nil }
            return NSImage(data: data)
        case .command, .appShortcut, .launcherAction, .snippetEntry:
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
        case .clipboardEntry:
            return "Clipboard"
        case .snippetEntry:
            return "Snippets"
        }
    }

    var subtitle: String? {
        switch self {
        case .clipboardEntry(let item):
            switch item.kind {
            case .text:
                let preview = item.preview
                return preview.count > 60 ? String(preview.prefix(60)) + "..." : preview
            case .fileURL:
                return item.fileURL?.path
            case .image:
                return nil
            }
        case .snippetEntry(let snippet):
            return snippet.keyword
        default:
            return nil
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
        case snippets
        case windowPane

        var label: String {
            switch self {
            case .all: return "All"
            case .commands: return "Commands"
            case .shortcuts: return "Shortcuts"
            case .applications: return "Apps"
            case .clipboard: return "Clipboard"
            case .snippets: return "Snippets"
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
            case .snippets: return "text.append"
            case .windowPane: return "gearshape"
            }
        }

        static var visibleCases: [Category] {
            var cases: [Category] = [.all, .commands, .shortcuts, .applications]
            if AppSettings.launcherClipboardTab { cases.append(.clipboard) }
            if AppSettings.launcherSnippetsTab { cases.append(.snippets) }
            cases.append(.windowPane)
            return cases
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
    @Published var selectedCategory: Category = .all {
        didSet { selectedIndex = 0 }
    }
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

        if trimmed.isEmpty {
            if selectedCategory == .all {
                return []
            }
            return recentItems(for: selectedCategory)
        }

        let ranked = FuzzyMatch.ranked(items, query: query) { $0.title }
        return filterByCategory(ranked)
    }

    private func filterByCategory(_ items: [LauncherItem]) -> [LauncherItem] {
        switch selectedCategory {
        case .all:
            return items
        case .commands:
            return items.filter { $0.section == "Commands" || $0.section == "Actions" }
        case .shortcuts:
            return items.filter { $0.section == "Shortcuts" }
        case .applications:
            return items.filter { $0.section == "Applications" }
        case .clipboard:
            return items.filter { $0.section == "Clipboard" }
        case .snippets:
            return items.filter { $0.section == "Snippets" }
        case .windowPane:
            return items.filter { $0.section == "WindowPane" }
        }
    }

    private func recentItems(for category: Category) -> [LauncherItem] {
        switch category {
        case .clipboard:
            var entries: [LauncherItem] = [.launcherAction(.clipboardHistory)]
            entries.append(contentsOf: ClipboardStore.shared.items.prefix(10).map { .clipboardEntry($0) })
            return entries
        case .snippets:
            return SnippetStore.shared.validSnippets.map { .snippetEntry($0) }
        default:
            break
        }

        let categoryItems = filterByCategory(items)
        let ids = categoryItems.map(\.id)
        let recentIDs = UsageTracker.shared.sortedByRecent(ids)
        let idOrder = Dictionary(uniqueKeysWithValues: recentIDs.enumerated().map { ($1, $0) })
        let maxResults = 8
        return categoryItems
            .sorted { (a, b) in
                let ia = idOrder[a.id] ?? Int.max
                let ib = idOrder[b.id] ?? Int.max
                if ia != ib { return ia < ib }
                return a.title.localizedCaseInsensitiveCompare(b.title) == .orderedAscending
            }
            .prefix(maxResults)
            .map { $0 }
    }

    func cycleCategory() {
        let cases = Category.visibleCases
        guard let currentIndex = cases.firstIndex(of: selectedCategory) else { return }
        selectedCategory = cases[(currentIndex + 1) % cases.count]
        selectedIndex = 0
    }

    func cycleCategoryBackward() {
        let cases = Category.visibleCases
        guard let currentIndex = cases.firstIndex(of: selectedCategory) else { return }
        let count = cases.count
        selectedCategory = cases[(currentIndex - 1 + count) % count]
        selectedIndex = 0
    }

    func selectCategory(_ category: Category) {
        selectedCategory = category
        selectedIndex = 0
    }

    var sections: [LauncherSection] {
        let filtered = self.filtered
        return ["Commands", "Actions", "Shortcuts", "Applications", "Clipboard", "Snippets", "WindowPane"].compactMap { title in
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
