import TrastCore
import AppKit
import KeyboardShortcuts
import SwiftUI
import Combine

extension Notification.Name {
    static let openSettings = Notification.Name("TrastOpenSettings")
}

final class LauncherController: NSObject, NSWindowDelegate {
    static let shared = LauncherController()

    private var panel: LauncherPanel?
    private let viewModel = LauncherViewModel()
    private var target: WindowRef?
    private var keyMonitor: Any?
    private var resizeCancellable: AnyCancellable?
    private var appsUpdateObserver: NSObjectProtocol?
    private var lastTargetFrame: NSRect?
    private var resizeScheduled = false
    private var lastLayoutSignature: LayoutSignature?

    /// Everything that determines the panel's content height. Selection and
    /// hover changes don't affect it, so they don't need a layout pass.
    private struct LayoutSignature: Equatable {
        let category: LauncherViewModel.Category
        let sectionTitles: [String]
        let rowCount: Int
        // Tool-internal modes swap views of very different heights under the
        // same category (transformer capturing → ready; scratchpad editor →
        // notes list) — without them in the signature the panel keeps the
        // height measured for the previous mode and clips the new content.
        let transformerState: LauncherViewModel.TransformerState
        let scratchpadMode: LauncherViewModel.ScratchpadMode
    }

    override private init() {
        super.init()
        // Apps installed while Trast runs: the scanner's directory watcher
        // refreshes the cache in the background; if the panel is open, pick
        // up the new items live, otherwise the next open reads the fresh cache.
        appsUpdateObserver = NotificationCenter.default.addObserver(
            forName: AppScanner.appsDidUpdate,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            guard let self, self.panel?.isVisible == true else { return }
            self.viewModel.items = self.makeItems()
        }
    }

    func toggle() {
        if panel?.isVisible == true {
            close()
        } else {
            show()
        }
    }

    func show() {
        target = WindowManipulator.frontmostWindow()
        viewModel.items = makeItems()
        viewModel.reset()

        let panel = ensurePanel()
        resizePanelToFit()
        panel.makeKeyAndOrderFront(nil)

        // "On open" setting: land on the unified tools/recents view instead
        // of a bare search bar.
        if AppSettings.launcherOpensToTools {
            viewModel.showRecentActivity()
        }
    }

    func showClipboard() {
        if panel?.isVisible == true, viewModel.selectedCategory == .clipboard {
            close()
        } else {
            show()
            DispatchQueue.main.async { [weak self] in
                self?.viewModel.selectCategory(.clipboard)
            }
        }
    }

    func showScratchpad() {
        if panel?.isVisible == true, viewModel.selectedCategory == .scratchpad {
            close()
        } else {
            show()
            DispatchQueue.main.async { [weak self] in
                self?.viewModel.selectCategory(.scratchpad)
            }
        }
    }

    private func makeItems() -> [LauncherItem] {
        var items: [LauncherItem] = []
        items.append(contentsOf: CommandStore.shared.commands.map { command in
            .command(command, hotkeyName: HotkeyManager.name(for: command.id))
        })
        items.append(contentsOf: WindowAction.all.map { action in
            .command(action.command, hotkeyName: HotkeyManager.actionName(action.id))
        })
        items.append(contentsOf: AppShortcutStore.shared.validShortcuts.filter { $0.kind != .app }.map { shortcut in
            .appShortcut(shortcut, hotkeyName: HotkeyManager.appJumpName(for: shortcut.id))
        })
        items.append(contentsOf: installedAppItems())
        items.append(contentsOf: LauncherAction.allCases.map { .launcherAction($0) })
        items.append(contentsOf: SnippetStore.shared.validSnippets.map { .snippetEntry($0) })
        items.append(contentsOf: ClipboardStore.shared.items.map { .clipboardEntry($0) })
        items.append(contentsOf: LauncherViewModel.Category.visibleCases.compactMap { category -> LauncherItem? in
            switch category {
            case .all, .trast:
                return nil
            default:
                return .categoryEntry(category)
            }
        })
        return items
    }

    private func installedAppItems() -> [LauncherItem] {
        let appShortcuts = AppShortcutStore.shared.validShortcuts.filter { $0.kind == .app }
        let shortcutByBundleID = Dictionary(uniqueKeysWithValues: appShortcuts.compactMap { s in
            s.bundleIdentifier.map { ($0, s) }
        })
        let shortcutByPath = Dictionary(uniqueKeysWithValues: appShortcuts.compactMap { s in
            s.bundleURL.map { ($0.path, s) }
        })

        return AppScanner.cachedApps().map { app in
            let existingShortcut = shortcutByBundleID[app.bundleIdentifier ?? ""]
                ?? shortcutByPath[app.bundleURL.path]
            let hotkeyName: KeyboardShortcuts.Name
            if let existingShortcut {
                hotkeyName = HotkeyManager.appJumpName(for: existingShortcut.id)
            } else {
                hotkeyName = KeyboardShortcuts.Name("installedApp.\(app.id)")
            }
            return LauncherItem.installedApp(app, hotkeyName: hotkeyName)
        }
    }

    func close() {
        panel?.orderOut(nil)
    }

    /// Entering the transformer captures the selection: Accessibility first
    /// (works while the panel is open), pasteboard borrow as fallback — the
    /// panel is hidden for the synthetic Cmd+C, since posted keyboard events
    /// go to the app owning the key window, which is Trast while the panel
    /// is up. The panel is brought back when the fallback completes.
    func enterTextTransformer() {
        viewModel.beginTextTransformerCapture()
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let self else { return }
            let axText = TextTransformerController.shared.axSelectedText()
            if let axText, !axText.isEmpty {
                DispatchQueue.main.async {
                    self.finishTransformerCapture(axText)
                }
                return
            }
            DispatchQueue.main.async {
                self.panel?.orderOut(nil)
            }
            TextTransformerController.shared.captureViaPasteboard { [weak self] text in
                DispatchQueue.main.async {
                    self?.panel?.makeKeyAndOrderFront(nil)
                    self?.finishTransformerCapture(text)
                }
            }
        }
    }

    private func finishTransformerCapture(_ text: String?) {
        viewModel.finishTextTransformerCapture(text)
    }

    func showTextTransformer() {
        if panel?.isVisible == true, viewModel.selectedCategory == .textTransformer {
            close()
        } else {
            show()
            viewModel.selectCategory(.textTransformer)
        }
    }

    func showAIChat() {
        if panel?.isVisible == true, viewModel.selectedCategory == .aiChat {
            close()
        } else {
            show()
            viewModel.selectCategory(.aiChat)
        }
    }

    /// Applies the highlighted transformation to the captured selection:
    /// closes the panel first (the target app stays frontmost — the panel
    /// is non-activating), then replaces the selection and shows feedback.
    func applySelectedTransform() {
        guard viewModel.selectedCategory == .textTransformer,
              let transform = viewModel.selectedTransform() else { return }
        let text = viewModel.transformerText
        close()
        TextTransformerController.shared.apply(transform, to: text)
        HUD.show("Selection replaced")
    }

    func handleEscape() {
        if viewModel.selectedCategory != .all {
            // From a tool or category, back to the All search.
            viewModel.selectCategory(.all)
        } else if viewModel.showsRecentActivity {
            // Collapse the tools/recents view back to the empty search bar.
            viewModel.dismissRecentActivity()
        } else {
            close()
        }
    }

    /// The row the options menu (Cmd+K) applies to — set when the menu
    /// opens, consumed by its action.
    private var optionsItemID: String?

    /// Cmd+K: shows an NSMenu with the highlighted row's options — the same
    /// actions as the right-click context menu, driven from the keyboard.
    /// Pops just under the search bar (the row itself may be anywhere in the
    /// scrolled list), with the item's title as the menu's header so the
    /// association is explicit.
    private func showOptionsForSelectedItem() {
        guard               viewModel.selectedCategory != .scratchpad,
              let item = viewModel.selectedItem(),
              viewModel.isFavoritable(item) else { return }

        let menu = NSMenu()
        let header = NSMenuItem(title: item.title, action: nil, keyEquivalent: "")
        header.isEnabled = false
        menu.addItem(header)
        menu.addItem(.separator())
        let favoriteItem = NSMenuItem(
            title: viewModel.isFavorite(item) ? "Remove from Favorites" : "Add to Favorites",
            action: #selector(toggleSelectedFavorite),
            keyEquivalent: ""
        )
        favoriteItem.target = self
        menu.addItem(favoriteItem)
        optionsItemID = item.id

        guard let contentView = panel?.contentView else { return }
        let point = NSPoint(x: 24, y: contentView.bounds.height - 56)
        menu.popUp(positioning: nil, at: point, in: contentView)
    }

    @objc private func toggleSelectedFavorite() {
        guard let optionsItemID else { return }
        viewModel.toggleFavorite(optionsItemID)
        self.optionsItemID = nil
    }

    private func handle(_ item: LauncherItem) {
        UsageTracker.shared.record(item.id)
        switch item {
        case .command(let command, _):
            close()
            CommandApplier.shared.apply(command, target: target ?? WindowManipulator.frontmostWindow())
        case .appShortcut(let shortcut, _):
            close()
            AppShortcutStore.shared.activate(shortcut.id)
        case .installedApp(let app, _):
            close()
            let configuration = NSWorkspace.OpenConfiguration()
            configuration.activates = true
            configuration.hides = false
            NSWorkspace.shared.openApplication(at: app.bundleURL, configuration: configuration) { runningApp, error in
                if let error {
                    Task { @MainActor in HUD.show(error.localizedDescription) }
                    return
                }
                runningApp?.activate(options: [.activateAllWindows])
            }
        case .launcherAction(let action):
            if case .clipboardHistory = action {
                viewModel.selectCategory(.clipboard)
                return
            }
            close()
            switch action {
            case .settings:
                openSettingsWindow()
            case .checkForUpdates:
                UpdateChecker.checkForUpdates()
            case .quit:
                NSApp.terminate(nil)
            case .clipboardHistory:
                break
            }
        case .clipboardEntry(let item):
            close()
            pasteClipboardItem(item)
        case .snippetEntry(let snippet):
            close()
            let clipboard = NSPasteboard.general.string(forType: .string) ?? ""
            let resolved = SnippetTemplate.resolve(snippet.content, clipboardContent: clipboard)
            NSPasteboard.general.clearContents()
            NSPasteboard.general.setString(resolved, forType: .string)
            HUD.show("Snippet copied to clipboard")
        case .calculatorResult(_, _, let value):
            close()
            let pasteboard = NSPasteboard.general
            pasteboard.clearContents()
            pasteboard.setString(value, forType: .string)
            HUD.show("Copied")
        case .categoryEntry(let category):
            viewModel.selectCategory(category)
        case .toolEntry(let category, _):
            viewModel.selectCategory(category)
        }
    }

    private func ensurePanel() -> LauncherPanel {
        if let panel { return panel }

        let panel = LauncherPanel(
            contentRect: NSRect(x: 0, y: 0, width: 640, height: 400),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        panel.isReleasedWhenClosed = false
        panel.isMovableByWindowBackground = false
        panel.hidesOnDeactivate = false
        panel.level = .floating
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        panel.delegate = self
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = true

        let hostingView = NSHostingView(
            rootView: LauncherView(viewModel: viewModel) { [weak self] item in
                self?.handle(item)
            }
        )
        hostingView.translatesAutoresizingMaskIntoConstraints = false
        panel.contentView = hostingView

        self.panel = panel
        installKeyMonitor()
        observeContentChanges()
        return panel
    }

    private func observeContentChanges() {
        resizeCancellable = viewModel.objectWillChange.sink { [weak self] _ in
            // One input change fires objectWillChange several times (query,
            // selection, results); coalesce them into a single resize pass.
            guard let self, !self.resizeScheduled else { return }
            self.resizeScheduled = true
            DispatchQueue.main.async { [weak self] in
                guard let self else { return }
                self.resizeScheduled = false
                self.resizePanelToFit()
            }
        }
    }

    private func resizePanelToFit() {
        guard let panel, let hostingView = panel.contentView as? NSHostingView<LauncherView> else { return }

        let signature = LayoutSignature(
            category: viewModel.selectedCategory,
            sectionTitles: viewModel.sections.map(\.title),
            rowCount: viewModel.filtered.count,
            transformerState: viewModel.transformerState,
            scratchpadMode: viewModel.scratchpadMode
        )
        // The content height can't have changed (selection move, hover);
        // skip the fittingSize measurement, which forces a full layout pass.
        if signature == lastLayoutSignature, lastTargetFrame != nil { return }
        lastLayoutSignature = signature

        let fittingSize = hostingView.fittingSize
        var height = min(fittingSize.height, 440)
        height = max(height, 52)
        guard let target = targetFrame(height: height) else { return }
        // Skip when the destination is unchanged: objectWillChange fires on
        // every keystroke and selection move, and restarting the easeInOut
        // resize from a mid-flight frame makes the panel visibly stutter.
        guard target != lastTargetFrame else { return }
        lastTargetFrame = target

        // Animate only large jumps (mode switches) in sync with
        // LauncherViewModel.modeAnimation: an instant setContentSize of that
        // size lets the window's material layer draw square corners for a
        // frame before SwiftUI re-applies the corner mask. Small deltas
        // (search results growing/shrinking) snap, which reads as smooth
        // incremental tracking and avoids animation pile-up while typing.
        if panel.isVisible, abs(target.height - panel.frame.height) > 60 {
            NSAnimationContext.runAnimationGroup { context in
                context.duration = 0.18
                context.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
                panel.animator().setFrame(target, display: true)
            }
        } else {
            panel.setFrame(target, display: true)
        }
    }

    private func targetFrame(height: CGFloat) -> NSRect? {
        guard let panel else { return nil }
        let mouse = NSEvent.mouseLocation
        let screen = NSScreen.screens.first { $0.frame.contains(mouse) } ?? NSScreen.main
        guard let screen else { return nil }
        let visible = screen.visibleFrame
        let scale = screen.backingScaleFactor
        // Pixel-align size and origin to avoid sub-pixel jitter on non-HiDPI displays.
        let alignedWidth = (panel.frame.width * scale).rounded() / scale
        let alignedHeight = (height * scale).rounded() / scale
        let x = visible.midX - alignedWidth / 2
        let y = visible.maxY - visible.height * 0.32 - alignedHeight
        let alignedX = (x * scale).rounded() / scale
        let alignedY = (y * scale).rounded() / scale
        return NSRect(x: alignedX, y: alignedY, width: alignedWidth, height: alignedHeight)
    }

    private func installKeyMonitor() {
        guard keyMonitor == nil else { return }
        keyMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            guard let self, let panel = self.panel, panel.isKeyWindow else { return event }

            if event.modifierFlags.contains(.command), event.keyCode == 43 {
                self.close()
                self.openSettingsWindow()
                return nil
            }

            if event.modifierFlags.contains(.command) {
                let numberKeyCodes: [UInt16] = [18, 19, 20, 21, 23, 22, 26, 28, 25]
                if let index = numberKeyCodes.firstIndex(of: event.keyCode) {
                    self.viewModel.selectCategoryByIndex(index)
                    return nil
                }
                // Cmd+K — options for the highlighted row, the keyboard
                // equivalent of the right-click context menu.
                if event.keyCode == 40 {
                    self.showOptionsForSelectedItem()
                    return nil
                }
            }

            // AI Chat placeholder view: Esc and Tab navigate, everything else
            // is swallowed (no text field to receive typing yet).
            if self.viewModel.selectedCategory == .aiChat {
                switch event.keyCode {
                case 53:
                    self.handleEscape()
                    return nil
                case 48:
                    self.handleEscape()
                    return nil
                default:
                    return nil
                }
            }

            // Text Transformer mode: arrows pick a transformation, Return
            // replaces the selection, everything else is swallowed (there
            // is no text field to receive typing).
            if self.viewModel.selectedCategory == .textTransformer {
                switch event.keyCode {
                case 125:
                    self.viewModel.moveTransformSelection(1)
                    return nil
                case 126:
                    self.viewModel.moveTransformSelection(-1)
                    return nil
                case 36, 76:
                    self.applySelectedTransform()
                    return nil
                case 53:
                    self.handleEscape()
                    return nil
                case 48:
                    self.handleEscape()
                    return nil
                default:
                    return nil
                }
            }

            // Scratchpad mode: the editor needs Return, arrows, and all text
            // keys; only Esc and Tab are launcher navigation. Cmd+N creates
            // a note, Cmd+P toggles the notes list; the list handles its own
            // navigation.
            if self.viewModel.selectedCategory == .scratchpad {
                if event.modifierFlags.contains(.command), event.keyCode == 45 {
                    self.viewModel.createNote()
                    return nil
                }
                if event.modifierFlags.contains(.command), event.keyCode == 35 {
                    self.viewModel.toggleNotesList()
                    return nil
                }
                switch self.viewModel.scratchpadMode {
                case .editor:
                    switch event.keyCode {
                    case 53:
                        self.handleEscape()
                        return nil
                    case 48:
                        self.handleEscape()
                        return nil
                    default:
                        return event
                    }
                case .notesList:
                    switch event.keyCode {
                    case 125:
                        self.viewModel.moveNotesSelection(1)
                        return nil
                    case 126:
                        self.viewModel.moveNotesSelection(-1)
                        return nil
                    case 36, 76:
                        self.viewModel.openSelectedNote()
                        return nil
                    case 53:
                        self.viewModel.scratchpadMode = .editor
                        return nil
                    case 48:
                        self.handleEscape()
                        return nil
                    default:
                        // No visible editor to receive typing while the
                        // list is up.
                        return nil
                    }
                }
            }

            switch event.keyCode {
            case 48:
                // Tab opens the unified tools/recents view — same as ↓ and
                // the search bar's list button — when the search is empty.
                if self.viewModel.selectedCategory == .all,
                   self.viewModel.query.trimmingCharacters(in: .whitespaces).isEmpty,
                   self.viewModel.filtered.isEmpty {
                    self.viewModel.showRecentActivity()
                }
                return nil
            case 123, 124, 125, 126:
                if event.keyCode == 125 {
                    // Down from an empty All search opens the tools/recents
                    // view instead of doing nothing.
                    if self.viewModel.selectedCategory == .all,
                       self.viewModel.query.trimmingCharacters(in: .whitespaces).isEmpty,
                       self.viewModel.filtered.isEmpty {
                        self.viewModel.showRecentActivity()
                        return nil
                    }
                    self.viewModel.moveSelection(1)
                    return nil
                }
                if event.keyCode == 126 {
                    self.viewModel.moveSelection(-1)
                    return nil
                }
                return event
            case 36, 76:
                if let item = self.viewModel.selectedItem() {
                    self.handle(item)
                }
                return nil
            case 53:
                self.handleEscape()
                return nil
            default:
                return event
            }
        }
    }

    func windowDidResignKey(_ notification: Notification) {
        close()
    }

    private func openSettingsWindow() {
        // The observer on the menu-bar label (StatusBarLabel) owns the full
        // open sequence — the .menu-style MenuBarExtra content that used to
        // observe this is only instantiated while the menu is open, so it
        // never fired from here.
        NotificationCenter.default.post(name: .openSettings, object: nil)
    }

    private func pasteClipboardItem(_ item: ClipboardItem) {
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()

        switch item.kind {
        case .text:
            if let text = item.textContent {
                pasteboard.setString(text, forType: .string)
            }
        case .image:
            if let data = item.imageData {
                pasteboard.setData(data, forType: .tiff)
            }
        case .fileURL:
            if let url = item.fileURL {
                pasteboard.writeObjects([url as NSURL])
            }
        }

        let source = CGEventSource(stateID: .hidSystemState)
        let vDown = CGEvent(keyboardEventSource: source, virtualKey: 9, keyDown: true)
        vDown?.flags = .maskCommand
        let vUp = CGEvent(keyboardEventSource: source, virtualKey: 9, keyDown: false)
        vUp?.flags = .maskCommand
        vDown?.post(tap: .cghidEventTap)
        vUp?.post(tap: .cghidEventTap)
    }
}

final class LauncherPanel: NSPanel {
    override var canBecomeKey: Bool { true }
}
