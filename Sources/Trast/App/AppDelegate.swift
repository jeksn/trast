import AppKit
import TrastCore

final class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        ConfigMigration.migrateIfNeeded()
        AppScanner.refresh()
        ClipboardMonitor.shared.start()
        SnippetExpander.shared.start()
        HotkeyManager.shared.registerAll(for: CommandStore.shared)
        HotkeyManager.shared.registerAllAppJumps(for: AppShortcutStore.shared)

        NSAppleEventManager.shared().setEventHandler(
            self,
            andSelector: #selector(handleGetURLEvent(_:withReplyEvent:)),
            forEventClass: AEEventClass(0x4755524C),
            andEventID: AEEventID(0x4755524C)
        )

        if AppSettings.autoCheckUpdates {
            UpdateChecker.checkForUpdatesOnLaunch()
        }
    }

    @objc private func handleGetURLEvent(_ event: NSAppleEventDescriptor, withReplyEvent reply: NSAppleEventDescriptor) {
        guard
            let urlString = event.paramDescriptor(forKeyword: AEKeyword(0x2D2D2D2D))?.stringValue,
            let url = URL(string: urlString)
        else { return }
        URLDispatcher.handle(url)
    }
}
