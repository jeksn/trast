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
    case toolEntry(LauncherViewModel.Category, number: Int)
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
        case .toolEntry(let category, _):
            return "tool.\(category.rawValue)"
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
        case .toolEntry(let category, _):
            return category.label
        case .calculatorResult(let title, _, _):
            return title
        }
    }

    var hotkeyName: KeyboardShortcuts.Name? {
        switch self {
        case .command(_, let name), .appShortcut(_, let name), .installedApp(_, let name):
            return name
        case .launcherAction, .clipboardEntry, .snippetEntry, .categoryEntry, .toolEntry, .calculatorResult:
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
        case .toolEntry(let category, _):
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
        case .command, .appShortcut, .launcherAction, .snippetEntry, .categoryEntry, .toolEntry, .calculatorResult:
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
        case .toolEntry:
            return "Tools"
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
    /// The scratchpad tool has two modes: editing the current note, and the
    /// notes list (Cmd+P) for switching between them.
    enum ScratchpadMode {
        case editor
        case notesList
    }

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
        case textTransformer
        case aiChat

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
            case .textTransformer: return "Text Transformer"
            case .aiChat: return "AI Chat"
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
            case .textTransformer: return "textformat"
            case .aiChat: return "sparkles"
            }
        }

        static var visibleCases: [Category] {
            var cases: [Category] = [.all, .commands, .shortcuts, .applications]
            if AppSettings.launcherClipboardTab { cases.append(.clipboard) }
            if AppSettings.launcherSnippetsTab { cases.append(.snippets) }
            cases.append(.scratchpad)
            cases.append(.textTransformer)
            cases.append(.aiChat)
            cases.append(.trast)
            return cases
        }

        /// Interactive utilities rendered as tiles in the actions view —
        /// the zone tools live in. Tiles wrap into a grid, so more tools
        /// never means a longer list. AI Chat shows a coming-soon view until
        /// the chat is built.
        static var toolCases: [Category] {
            var cases: [Category] = []
            if AppSettings.launcherClipboardTab { cases.append(.clipboard) }
            if AppSettings.launcherSnippetsTab { cases.append(.snippets) }
            cases.append(.scratchpad)
            cases.append(.textTransformer)
            cases.append(.aiChat)
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
        didSet { selectedIndex = 0; updateResults() }
    }
    @Published var query = "" {
        didSet { selectedIndex = 0; updateResults() }
    }
    @Published var selectedIndex = 0
    @Published var focusToken = UUID()
    @Published var showsRecentActivity = false
    @Published var scratchpadMode: ScratchpadMode = .editor
    @Published var notesSelectedIndex = 0

    /// The Text Transformer tool captures the frontmost app's selection on
    /// entry and previews transformations over it.
    enum TransformerState {
        case capturing
        case noSelection
        case ready
    }

    @Published var transformerState: TransformerState = .capturing
    @Published var transformerText: String = ""
    @Published var transformSelectedIndex = 0
    @Published private(set) var filtered: [LauncherItem] = []
    @Published private(set) var sections: [LauncherSection] = []
    /// Mirrors `FavoritesStore` so rows re-render when a favorite toggles.
    @Published private(set) var favorites: Set<String> = FavoritesStore.shared.ids

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
        showsRecentActivity = false
        scratchpadMode = .editor
        notesSelectedIndex = 0
        favorites = FavoritesStore.shared.ids
    }

    // MARK: - Scratchpad notes

    /// Cmd+N / the New button: a fresh empty note, opened in the editor.
    func createNote() {
        NotesStore.shared.createNote()
        scratchpadMode = .editor
        notesSelectedIndex = 0
        focusToken = UUID()
    }

    /// Cmd+P: switch between the editor and the notes list.
    func toggleNotesList() {
        scratchpadMode = scratchpadMode == .notesList ? .editor : .notesList
        notesSelectedIndex = 0
        if scratchpadMode == .editor {
            focusToken = UUID()
        }
    }

    /// Opens a note from the list in the editor.
    func openNote(_ id: UUID) {
        NotesStore.shared.open(id: id)
        scratchpadMode = .editor
        focusToken = UUID()
    }

    func moveNotesSelection(_ delta: Int) {
        let count = NotesStore.shared.notes.count
        guard count > 0 else { return }
        notesSelectedIndex = (notesSelectedIndex + delta + count) % count
    }

    func openSelectedNote() {
        guard let note = NotesStore.shared.notes[safe: notesSelectedIndex] else { return }
        openNote(note.id)
    }

    // MARK: - Text Transformer

    /// Entering the tool clears state and starts capturing the frontmost
    /// app's selection (orchestrated by `LauncherController`, which owns the
    /// panel — the pasteboard fallback needs it hidden).
    func beginTextTransformerCapture() {
        transformerState = .capturing
        transformerText = ""
        transformSelectedIndex = 0
    }

    func finishTextTransformerCapture(_ text: String?) {
        guard selectedCategory == .textTransformer else { return }
        if let text, !text.isEmpty {
            transformerText = text
            transformerState = .ready
        } else {
            transformerState = .noSelection
        }
    }

    func moveTransformSelection(_ delta: Int) {
        let count = TextTransform.allCases.count
        guard count > 0 else { return }
        transformSelectedIndex = (transformSelectedIndex + delta + count) % count
    }

    func selectedTransform() -> TextTransform? {
        guard transformerState == .ready else { return nil }
        return TextTransform.allCases[safe: transformSelectedIndex]
    }

    /// Opens the recent-activity view (↓ with an empty query in All):
    /// favorites first, then the last-used items across everything.
    func showRecentActivity() {
        showsRecentActivity = true
        updateResults()
    }

    func isFavoritable(_ item: LauncherItem) -> Bool {
        switch item {
        case .calculatorResult, .clipboardEntry, .categoryEntry, .toolEntry:
            return false
        default:
            return true
        }
    }

    func isFavorite(_ item: LauncherItem) -> Bool {
        guard isFavoritable(item) else { return false }
        return favorites.contains(item.id)
    }

    func toggleFavorite(_ id: String) {
        FavoritesStore.shared.toggle(id)
        favorites = FavoritesStore.shared.ids
        updateResults()
    }

    /// Recomputes `filtered` and `sections` exactly once per input change.
    /// These are read repeatedly by the view body (once per row), so they are
    /// stored instead of computed. `filtered` is always the sections flattened
    /// in display order — the selection walks what's on screen, so no
    /// visible row can be skipped or visited out of order.
    private func updateResults() {
        let trimmed = query.trimmingCharacters(in: .whitespaces)

        if trimmed.isEmpty {
            if selectedCategory == .all {
                if showsRecentActivity {
                    let activity = recentActivityItems()
                    sections = Self.makeRecentSections(from: activity, favorites: favorites)
                    filtered = sections.flatMap { $0.items }
                } else {
                    filtered = []
                    sections = []
                }
                return
            }
            let recent = recentItems(for: selectedCategory)
            sections = Self.makeSections(from: recent)
            filtered = sections.flatMap { $0.items }
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
        sections = Self.makeSections(from: ranked)
        filtered = sections.flatMap { $0.items }
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
        case .textTransformer, .aiChat:
            return false
        }
    }

    private static let sectionOrder = ["Calculator", "Browse", "Window Commands", "Actions", "Shortcuts", "Applications", "Clipboard", "Snippets", "Trast"]

    private static func makeSections(from items: [LauncherItem]) -> [LauncherSection] {
        sectionOrder.compactMap { title in
            let sectionItems = items.filter { $0.section == title }
            return sectionItems.isEmpty ? nil : LauncherSection(title: title, items: sectionItems)
        }
    }

    /// Sections for the recent-activity view: tools first (the unified
    /// entry to every tool — same order as the actions grid), then
    /// favorites, then the remaining items grouped as usual.
    private static func makeRecentSections(from items: [LauncherItem], favorites: Set<String>) -> [LauncherSection] {
        func isTool(_ item: LauncherItem) -> Bool {
            if case .toolEntry = item { return true }
            return false
        }
        let toolItems = items.filter(isTool)
        let restItems = items.filter { !isTool($0) }
        let favoriteItems = restItems.filter { favorites.contains($0.id) }
        let recentItems = restItems.filter { !favorites.contains($0.id) }
        var result: [LauncherSection] = []
        if !toolItems.isEmpty {
            result.append(LauncherSection(title: "Tools", items: toolItems))
        }
        if !favoriteItems.isEmpty {
            result.append(LauncherSection(title: "Favorites", items: favoriteItems))
        }
        result.append(contentsOf: makeSections(from: recentItems))
        return result
    }

    /// The ↓ view: every tool as a compact row, then favorites (always
    /// shown, even with no usage), then up to ten recently used items.
    /// Category entries and calculator results are excluded — the list is
    /// what you did, not what you could browse.
    private func recentActivityItems() -> [LauncherItem] {
        let toolEntries = Category.toolCases.enumerated().map { index, category in
            LauncherItem.toolEntry(category, number: index + 1)
        }
        let candidates = index
            .filter { includesInCategory($0.item) }
            .map(\.item.item)
            .filter { item in
                if case .categoryEntry = item { return false }
                return true
            }
        let sorted = sortedByUsage(candidates)
        let favoriteItems = sorted.filter { favorites.contains($0.id) }
        let recentItems = sorted.filter { !favorites.contains($0.id) }.prefix(10)
        return toolEntries + favoriteItems + Array(recentItems)
    }

    private func sortedByUsage(_ items: [LauncherItem]) -> [LauncherItem] {
        let ids = items.map(\.id)
        let recentIDs = UsageTracker.shared.sortedByRecent(ids)
        let idOrder = Dictionary(uniqueKeysWithValues: recentIDs.enumerated().map { ($1, $0) })
        return items.sorted { a, b in
            let ia = idOrder[a.id] ?? Int.max
            let ib = idOrder[b.id] ?? Int.max
            if ia != ib { return ia < ib }
            return a.title.localizedCaseInsensitiveCompare(b.title) == .orderedAscending
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
        return sortedByUsage(categoryItems)
    }

    /// Cmd+1..5: open the tool at that position in `toolCases` — the same
    /// numbers the tool rows in the recents view badge with.
    func selectCategoryByIndex(_ index: Int) {
        let cases = Category.toolCases
        guard index >= 0, index < cases.count else { return }
        selectCategory(cases[index])
    }

    /// Collapses the recent-activity view back to an empty search bar
    /// (Esc from the recents view).
    func dismissRecentActivity() {
        showsRecentActivity = false
        updateResults()
    }

    func selectCategory(_ category: Category) {
        selectedCategory = category
        selectedIndex = 0
        query = ""
        focusToken = UUID()
        if category == .scratchpad {
            scratchpadMode = .editor
            notesSelectedIndex = 0
        }
        if category == .textTransformer {
            LauncherController.shared.enterTextTransformer()
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
