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

enum LauncherIconCache {
    private static let cache: NSCache<NSString, NSImage> = {
        let cache = NSCache<NSString, NSImage>()
        cache.countLimit = 100
        return cache
    }()

    /// Decoded clipboard thumbnails, cached by entry id so image rows don't
    /// re-decode their data on every render.
    static func clipboardImage(for item: ClipboardItem) -> NSImage? {
        guard item.kind == .image, let data = item.imageData else { return nil }
        let key = item.id.uuidString as NSString
        if let cached = cache.object(forKey: key) { return cached }
        guard let image = NSImage(data: data) else { return nil }
        cache.setObject(image, forKey: key)
        return image
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
    case calculatorResult(title: String, subtitle: String, valueToCopy: String)

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
        case .calculatorResult:
            return "calculator"
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
        case .calculatorResult(let title, _, _):
            return title
        }
    }

    var hotkeyName: KeyboardShortcuts.Name? {
        switch self {
        case .command(_, let name), .appShortcut(_, let name), .installedApp(_, let name):
            return name
        case .launcherAction, .clipboardEntry, .snippetEntry, .categoryEntry, .calculatorResult:
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
        case .calculatorResult:
            return "plus.forwardslash.minus"
        }
    }

    var iconImage: NSImage? {
        switch self {
        case .installedApp(let app, _):
            return app.icon
        case .clipboardEntry(let item):
            return LauncherIconCache.clipboardImage(for: item)
        case .command, .appShortcut, .launcherAction, .snippetEntry, .categoryEntry, .calculatorResult:
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
        case .calculatorResult:
            return "Calculator"
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
        case .calculatorResult(_, let subtitle, _):
            return subtitle
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
    /// A launch candidate with everything the search path needs resolved once
    /// when the item list is built, instead of on every keystroke.
    private struct SearchEntry {
        let item: LauncherItem
        let section: String
        let hotkeyDisplay: String?
    }
    enum Category: String, CaseIterable, Hashable {
        case all
        case commands
        case shortcuts
        case applications
        case clipboard
        case snippets
        case scratchpad
        case trast

        var label: String {
            switch self {
            case .all: return "All"
            case .commands: return "Window Commands"
            case .shortcuts: return "Shortcuts"
            case .applications: return "Apps"
            case .clipboard: return "Clipboard"
            case .snippets: return "Snippets"
            case .scratchpad: return "Scratchpad"
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
            case .scratchpad: return "square.and.pencil"
            case .trast: return "gearshape"
            }
        }

        static var visibleCases: [Category] {
            var cases: [Category] = [.all, .commands, .shortcuts, .applications]
            if AppSettings.launcherClipboardTab { cases.append(.clipboard) }
            if AppSettings.launcherSnippetsTab { cases.append(.snippets) }
            cases.append(.scratchpad)
            cases.append(.trast)
            return cases
        }

        /// Interactive utilities rendered as tiles in the actions view —
        /// the zone new tools (text transformer, AI chat) join. Tiles wrap
        /// into a grid, so more tools never means a longer list.
        static var toolCases: [Category] {
            var cases: [Category] = []
            if AppSettings.launcherClipboardTab { cases.append(.clipboard) }
            if AppSettings.launcherSnippetsTab { cases.append(.snippets) }
            cases.append(.scratchpad)
            return cases
        }

        /// Searchable item lists rendered as rows in the actions view.
        static var browseCases: [Category] {
            [.commands, .shortcuts, .applications, .trast]
        }

        /// The full keyboard navigation order for the actions view:
        /// tool tiles first, then browse rows. Cmd+number follows it.
        static var gridCases: [Category] {
            toolCases + browseCases
        }

        /// True when the category is rendered as a tool tile.
        var isTool: Bool {
            Self.toolCases.contains(self)
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
        didSet { selectedIndex = 0; updateResults() }
    }
    @Published var query = "" {
        didSet { selectedIndex = 0; updateResults() }
    }
    @Published var selectedIndex = 0
    @Published var focusToken = UUID()
    @Published var showsActions = false
    @Published var gridIndex = 0
    @Published private(set) var filtered: [LauncherItem] = []
    @Published private(set) var sections: [LauncherSection] = []

    var items: [LauncherItem] = [] {
        didSet { rebuildIndex(); updateResults() }
    }

    /// Precomputed search index: item list → search text, lowercased matching
    /// buffer, section, and resolved hotkey label, all computed once per
    /// item-list rebuild (every panel open) instead of per keystroke.
    private var index: [FuzzyMatch.Indexed<SearchEntry>] = []

    /// Hotkey display strings keyed by `LauncherItem.id` (which is the
    /// `KeyboardShortcuts.Name` for hotkey-carrying items).
    private var hotkeyDisplays: [String: String] = [:]

    func hotkeyDisplay(for item: LauncherItem) -> String? {
        guard let name = item.hotkeyName else { return nil }
        return hotkeyDisplays[name.rawValue]
    }

    private func rebuildIndex() {
        hotkeyDisplays.removeAll()
        index = items.map { item in
            let hotkeyDisplay = item.hotkeyName.flatMap {
                KeyboardShortcuts.getShortcut(for: $0)?.hyperDescription
            }
            if let hotkeyDisplay, let name = item.hotkeyName {
                hotkeyDisplays[name.rawValue] = hotkeyDisplay
            }
            let entry = SearchEntry(item: item, section: item.section, hotkeyDisplay: hotkeyDisplay)
            return FuzzyMatch.Indexed(item: entry, text: item.searchText)
        }
    }

    func reset() {
        placeholder = Self.placeholders.randomElement() ?? Self.placeholders[0]
        selectedCategory = .all
        query = ""
        selectedIndex = 0
        focusToken = UUID()
        showsActions = false
        gridIndex = 0
    }

    /// Recomputes `filtered` and `sections` exactly once per input change.
    /// These are read repeatedly by the view body (once per row), so they are
    /// stored instead of computed.
    private func updateResults() {
        let trimmed = query.trimmingCharacters(in: .whitespaces)

        if trimmed.isEmpty {
            if selectedCategory == .all {
                filtered = []
                sections = []
                return
            }
            let recent = recentItems(for: selectedCategory)
            filtered = recent
            sections = Self.makeSections(from: recent)
            return
        }

        // Scope to the category before ranking so an Apps search doesn't
        // fuzzy-score commands, snippets, and clipboard items.
        let scoped = index.filter { includesInCategory($0.item) }
        var ranked: [LauncherItem] = FuzzyMatch.rankedIndexed(scoped, query: query).map { $0.item.item }

        // Calculations (math, units, currency) show above other results in
        // the All category. Parsing is O(query length); the rates autoclosure
        // only evaluates when the query looks like a currency conversion.
        if selectedCategory == .all,
           let calc = Calculator.parse(
            query: trimmed,
            rates: ExchangeRateStore.shared.currentRates(),
            baseCurrency: AppSettings.baseCurrency,
            preferredUnits: AppSettings.preferredUnits
           ) {
            ranked.insert(.calculatorResult(
                title: calc.display,
                subtitle: calc.subtitle,
                valueToCopy: calc.clipboardValue
            ), at: 0)
        }
        filtered = ranked
        sections = Self.makeSections(from: ranked)
    }

    private func includesInCategory(_ entry: SearchEntry) -> Bool {
        switch selectedCategory {
        case .all:
            return entry.section != "Clipboard" && entry.section != "Snippets"
        case .commands:
            return entry.section == "Window Commands" || entry.section == "Actions"
        case .shortcuts:
            return entry.section == "Shortcuts"
        case .applications:
            return entry.section == "Applications"
        case .clipboard:
            return entry.section == "Clipboard"
        case .snippets:
            return entry.section == "Snippets"
        case .scratchpad:
            return false
        case .trast:
            if case .launcherAction(.clipboardHistory) = entry.item { return false }
            return entry.section == "Trast"
        }
    }

    private static let sectionOrder = ["Calculator", "Browse", "Window Commands", "Actions", "Shortcuts", "Applications", "Clipboard", "Snippets", "Trast"]

    private static func makeSections(from items: [LauncherItem]) -> [LauncherSection] {
        sectionOrder.compactMap { title in
            let sectionItems = items.filter { $0.section == title }
            return sectionItems.isEmpty ? nil : LauncherSection(title: title, items: sectionItems)
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

        let categoryItems = index.filter { includesInCategory($0.item) }.map(\.item.item)
        let ids = categoryItems.map(\.id)
        let recentIDs = UsageTracker.shared.sortedByRecent(ids)
        let idOrder = Dictionary(uniqueKeysWithValues: recentIDs.enumerated().map { ($1, $0) })
        return categoryItems
            .sorted { (a, b) in
                let ia = idOrder[a.id] ?? Int.max
                let ib = idOrder[b.id] ?? Int.max
                if ia != ib { return ia < ib }
                return a.title.localizedCaseInsensitiveCompare(b.title) == .orderedAscending
            }
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

    /// Left/right arrows: step within the tool tile row only (the row is
    /// horizontal, so sideways keys feel natural there). Clamps at the row
    /// edges instead of leaving the zone — browse rows are reached with
    /// up/down or Tab.
    func moveToolSelection(_ delta: Int) {
        let tools = Category.toolCases
        guard !tools.isEmpty, gridIndex < tools.count else { return }
        let next = min(max(gridIndex + delta, 0), tools.count - 1)
        guard next != gridIndex else { return }
        withAnimation(Self.modeAnimation) {
            gridIndex = next
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

    func moveSelection(_ delta: Int) {
        let count = filtered.count
        guard count > 0 else { return }
        selectedIndex = (selectedIndex + delta + count) % count
    }

    func selectedItem() -> LauncherItem? {
        filtered[safe: selectedIndex]
    }
}
