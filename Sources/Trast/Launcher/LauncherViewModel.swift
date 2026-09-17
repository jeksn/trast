import Foundation
import KeyboardShortcuts
import TrastCore
import AppKit
import SwiftUI

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
        case .quit: return "Quit Trast"
        }
    }

    var icon: String {
        switch self {
        case .settings: return "gearshape"
        case .clipboardHistory: return "clipboard"
        case .checkForUpdates: return "arrow.clockwise.circle"
        case .quit: return "power"
        }
    }

}

enum LauncherItem: Identifiable {
    case command(WindowCommand, hotkeyName: KeyboardShortcuts.Name)
    case appShortcut(AppShortcut, hotkeyName: KeyboardShortcuts.Name)
    case installedApp(AppChooserItem, hotkeyName: KeyboardShortcuts.Name)
    case launcherAction(LauncherAction)
    case clipboardEntry(ClipboardItem)
    case snippetEntry(Snippet)
    case categoryEntry(LauncherViewModel.Category)

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
        case .categoryEntry(let category):
            return "category.\(category.rawValue)"
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
        case .categoryEntry(let category):
            return category.label
        }
    }

    var hotkeyName: KeyboardShortcuts.Name? {
        switch self {
        case .command(_, let name), .appShortcut(_, let name), .installedApp(_, let name):
            return name
        case .launcherAction, .clipboardEntry, .snippetEntry, .categoryEntry:
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
        case .categoryEntry(let category):
            return category.icon
        }
    }

    var iconImage: NSImage? {
        switch self {
        case .installedApp(let app, _):
            return app.icon
        case .clipboardEntry(let item):
            guard item.kind == .image, let data = item.imageData else { return nil }
            return NSImage(data: data)
        case .command, .appShortcut, .launcherAction, .snippetEntry, .categoryEntry:
            return nil
        }
    }

    var searchText: String {
        switch self {
        case .clipboardEntry(let item):
            return "\(title)\n\(item.preview)"
        default:
            return subtitle.map { "\(title)\n\($0)" } ?? title
        }
    }

    var section: String {
        switch self {
        case .command(_, let name):
            return name.rawValue.hasPrefix("action.") ? "Actions" : "Window Commands"
        case .appShortcut:
            return "Shortcuts"
        case .installedApp:
            return "Applications"
        case .launcherAction:
            return "Trast"
        case .clipboardEntry:
            return "Clipboard"
        case .snippetEntry:
            return "Snippets"
        case .categoryEntry:
            return "Browse"
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
        case trast

        var label: String {
            switch self {
            case .all: return "All"
            case .commands: return "Window Commands"
            case .shortcuts: return "Shortcuts"
            case .applications: return "Apps"
            case .clipboard: return "Clipboard"
            case .snippets: return "Snippets"
            case .trast: return "Trast"
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
            case .trast: return "gearshape"
            }
        }

        static var visibleCases: [Category] {
            var cases: [Category] = [.all, .commands, .shortcuts, .applications]
            if AppSettings.launcherClipboardTab { cases.append(.clipboard) }
            if AppSettings.launcherSnippetsTab { cases.append(.snippets) }
            cases.append(.trast)
            return cases
        }

        static var gridCases: [Category] {
            visibleCases.filter { $0 != .all }
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
    @Published var showsActions = false
    @Published var gridIndex = 0

    var items: [LauncherItem] = []

    func reset() {
        placeholder = Self.placeholders.randomElement() ?? Self.placeholders[0]
        selectedCategory = .all
        query = ""
        selectedIndex = 0
        focusToken = UUID()
        showsActions = false
        gridIndex = 0
    }

    var filtered: [LauncherItem] {
        let trimmed = query.trimmingCharacters(in: .whitespaces)

        if trimmed.isEmpty {
            if selectedCategory == .all {
                return []
            }
            return recentItems(for: selectedCategory)
        }

        let ranked = FuzzyMatch.ranked(items, query: query) { $0.searchText }
        return filterByCategory(ranked)
    }

    private func filterByCategory(_ items: [LauncherItem]) -> [LauncherItem] {
        switch selectedCategory {
        case .all:
            return items.filter { item in
                switch item {
                case .clipboardEntry, .snippetEntry:
                    return false
                default:
                    return true
                }
            }
        case .commands:
            return items.filter { $0.section == "Window Commands" || $0.section == "Actions" }
        case .shortcuts:
            return items.filter { $0.section == "Shortcuts" }
        case .applications:
            return items.filter { $0.section == "Applications" }
        case .clipboard:
            return items.filter { $0.section == "Clipboard" }
        case .snippets:
            return items.filter { $0.section == "Snippets" }
        case .trast:
            return items.filter { $0.section == "Trast" }.filter {
                if case .launcherAction(.clipboardHistory) = $0 { return false }
                return true
            }
        }
    }

    private func recentItems(for category: Category) -> [LauncherItem] {
        switch category {
        case .clipboard:
            return ClipboardStore.shared.items.map { .clipboardEntry($0) }
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

    private static let modeAnimation = Animation.easeInOut(duration: 0.18)

    func enterActionsMode(atEnd: Bool = false) {
        let cases = Category.gridCases
        guard !cases.isEmpty else { return }
        if !showsActions {
            if let index = cases.firstIndex(of: selectedCategory) {
                gridIndex = index
            } else {
                gridIndex = atEnd ? cases.count - 1 : 0
            }
        }
        withAnimation(Self.modeAnimation) {
            showsActions = true
        }
    }

    func exitActionsMode() {
        withAnimation(Self.modeAnimation) {
            showsActions = false
            selectedCategory = .all
            gridIndex = 0
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) { [weak self] in
            self?.focusToken = UUID()
        }
    }

    func handleTab(shift: Bool) {
        let cases = Category.gridCases
        guard !cases.isEmpty else { return }

        if showsActions {
            let next = gridIndex + (shift ? -1 : 1)
            if next < 0 || next >= cases.count {
                exitActionsMode()
            } else {
                withAnimation(Self.modeAnimation) {
                    gridIndex = next
                }
            }
        } else if let currentIndex = cases.firstIndex(of: selectedCategory) {
            let next = currentIndex + (shift ? -1 : 1)
            if next < 0 || next >= cases.count {
                exitActionsMode()
            } else {
                withAnimation(Self.modeAnimation) {
                    gridIndex = next
                    showsActions = true
                }
            }
        } else {
            enterActionsMode(atEnd: shift)
        }
    }

    func moveGridSelection(_ delta: Int) {
        let count = Category.gridCases.count
        guard count > 0 else { return }
        withAnimation(Self.modeAnimation) {
            gridIndex = (gridIndex + delta + count) % count
        }
    }

    func selectGridCategory() {
        guard let category = Category.gridCases[safe: gridIndex] else { return }
        selectCategory(category)
    }

    func selectCategoryByIndex(_ index: Int) {
        let cases = Category.gridCases
        guard index >= 0, index < cases.count else { return }
        selectCategory(cases[index])
    }

    func selectCategory(_ category: Category) {
        selectedCategory = category
        selectedIndex = 0
        query = ""
        showsActions = false
        focusToken = UUID()
    }

    var sections: [LauncherSection] {
        let filtered = self.filtered
        return ["Browse", "Window Commands", "Actions", "Shortcuts", "Applications", "Clipboard", "Snippets", "Trast"].compactMap { title in
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
