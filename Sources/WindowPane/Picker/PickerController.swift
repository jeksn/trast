import WindowPaneCore
import AppKit
import KeyboardShortcuts
import SwiftUI
import Combine

extension Notification.Name {
    static let openSettings = Notification.Name("WindowPaneOpenSettings")
}

final class PickerController: NSObject, NSWindowDelegate {
    static let shared = PickerController()

    private var panel: PickerPanel?
    private let viewModel = PickerViewModel()
    private var target: WindowRef?
    private var keyMonitor: Any?
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

    private func makeItems() -> [PickerItem] {
        var items: [PickerItem] = []
        items.append(contentsOf: CommandStore.shared.commands.map { command in
            .command(command, hotkeyName: HotkeyManager.name(for: command.id))
        })
        items.append(contentsOf: WindowAction.all.map { action in
            .command(action.command, hotkeyName: HotkeyManager.actionName(action.id))
        })
        items.append(contentsOf: AppShortcutStore.shared.validShortcuts.map { shortcut in
            .appShortcut(shortcut, hotkeyName: HotkeyManager.appJumpName(for: shortcut.id))
        })
        items.append(contentsOf: installedAppItems())
        items.append(contentsOf: PickerAction.allCases.map { .pickerAction($0) })
        return items
    }

    private func installedAppItems() -> [PickerItem] {
        let appShortcuts = AppShortcutStore.shared.validShortcuts.filter { $0.kind == .app }
        let existingBundleIDs = Set(appShortcuts.compactMap { $0.bundleIdentifier })
        let existingPaths = Set(appShortcuts.compactMap { $0.bundleURL?.path })

        return AppScanner.cachedApps().compactMap { app in
            if let bid = app.bundleIdentifier, existingBundleIDs.contains(bid) { return nil }
            if existingPaths.contains(app.bundleURL.path) { return nil }
            return PickerItem.installedApp(app, hotkeyName: KeyboardShortcuts.Name("installedApp.\(app.id)"))
        }
    }

    func close() {
        panel?.orderOut(nil)
    }

    private func handle(_ item: PickerItem) {
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
        case .pickerAction(let action):
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
        }
    }

    private func ensurePanel() -> PickerPanel {
        if let panel { return panel }

        let panel = PickerPanel(
            contentRect: NSRect(x: 0, y: 0, width: 640, height: 400),
            styleMask: [.titled, .fullSizeContentView, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        panel.titleVisibility = .hidden
        panel.titlebarAppearsTransparent = true
        panel.standardWindowButton(.closeButton)?.isHidden = true
        panel.standardWindowButton(.miniaturizeButton)?.isHidden = true
        panel.standardWindowButton(.zoomButton)?.isHidden = true
        panel.isReleasedWhenClosed = false
        panel.isMovableByWindowBackground = false
        panel.hidesOnDeactivate = false
        panel.level = .floating
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        panel.delegate = self

        let hostingView = NSHostingView(
            rootView: PickerView(viewModel: viewModel) { [weak self] item in
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
            DispatchQueue.main.async {
                self?.resizePanelToFit()
            }
        }
    }

    private func resizePanelToFit() {
        guard let panel, let hostingView = panel.contentView as? NSHostingView<PickerView> else { return }
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
            switch event.keyCode {
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

    func windowDidResignKey(_ notification: Notification) {
        close()
    }

    private func openSettingsWindow() {
        DispatchQueue.main.async {
            NotificationCenter.default.post(name: .openSettings, object: nil)
        }
    }
}

final class PickerPanel: NSPanel {
    override var canBecomeKey: Bool { true }
}
