import WindowPaneCore
import AppKit
import KeyboardShortcuts
import SwiftUI
import Combine

extension Notification.Name {
    static let openSettings = Notification.Name("WindowPaneOpenSettings")
}

final class LauncherController: NSObject, NSWindowDelegate {
    static let shared = LauncherController()

    private var panel: LauncherPanel?
    private let viewModel = LauncherViewModel()
    private var target: WindowRef?
    private var keyMonitor: Any?
    private var flagsMonitor: Any?
    private var resizeCancellable: AnyCancellable?

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
        items.append(contentsOf: ClipboardStore.shared.items.prefix(20).map { .clipboardEntry($0) })
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
            close()
            switch action {
            case .settings:
                openSettingsWindow()
            case .clipboardHistory:
                ClipboardController.shared.show()
            case .checkForUpdates:
                UpdateChecker.checkForUpdates()
            case .quit:
                NSApp.terminate(nil)
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
        installFlagsMonitor()
        observeContentChanges()
        return panel
    }

    private func observeContentChanges() {
        resizeCancellable = viewModel.objectWillChange.sink { [weak self] _ in
            DispatchQueue.main.async {
                self?.resizePanelToFit()
            }
        }
    }

    private func resizePanelToFit() {
        guard let panel, let hostingView = panel.contentView as? NSHostingView<LauncherView> else { return }
        let fittingSize = hostingView.fittingSize
        var height = min(fittingSize.height, 440)
        height = max(height, 52)
        panel.setContentSize(CGSize(width: 640, height: height))
        reposition(panel)
    }

    private func reposition(_ panel: NSPanel) {
        let mouse = NSEvent.mouseLocation
        let screen = NSScreen.screens.first { $0.frame.contains(mouse) } ?? NSScreen.main
        guard let screen else { return }
        let visible = screen.visibleFrame
        let x = visible.midX - panel.frame.width / 2
        let y = visible.maxY - visible.height * 0.32 - panel.frame.height
        panel.setFrameOrigin(NSPoint(x: x, y: y))
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
            }

            switch event.keyCode {
            case 48:
                if event.modifierFlags.contains(.shift) {
                    self.viewModel.cycleCategoryBackward()
                } else {
                    self.viewModel.cycleCategory()
                }
                return nil
            case 125:
                self.viewModel.moveSelection(1)
                return nil
            case 126:
                self.viewModel.moveSelection(-1)
                return nil
            case 36, 76:
                if let item = self.viewModel.selectedItem() {
                    self.handle(item)
                }
                return nil
            case 53:
                self.close()
                return nil
            default:
                return event
            }
        }
    }

    private func installFlagsMonitor() {
        guard flagsMonitor == nil else { return }
        flagsMonitor = NSEvent.addLocalMonitorForEvents(matching: .flagsChanged) { [weak self] event in
            guard let self, let panel = self.panel, panel.isKeyWindow else { return event }
            self.viewModel.showTabNumbers = event.modifierFlags.contains(.command)
            return event
        }
    }

    func windowDidResignKey(_ notification: Notification) {
        close()
    }

    private func openSettingsWindow() {
        DispatchQueue.main.async {
            NSApp.activate(ignoringOtherApps: true)
            NotificationCenter.default.post(name: .openSettings, object: nil)
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
                NSApp.activate(ignoringOtherApps: true)
                NSApp.windows
                    .first { $0.title == "WindowPane" }?
                    .makeKeyAndOrderFront(nil)
            }
        }
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
