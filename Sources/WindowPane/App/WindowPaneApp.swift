import WindowPaneCore
import SwiftUI
import KeyboardShortcuts

@main
struct WindowPaneApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @StateObject private var store = CommandStore.shared
    @StateObject private var appShortcutStore = AppShortcutStore.shared
    @StateObject private var snippetStore = SnippetStore.shared

    var body: some Scene {
        MenuBarExtra {
            MenuContent()
                .environmentObject(store)
                .environmentObject(appShortcutStore)
        } label: {
            Image(nsImage: StatusBarIcon.image)
        }
        .menuBarExtraStyle(.menu)

        Window("WindowPane Settings", id: "settings") {
            SettingsView()
                .environmentObject(store)
                .environmentObject(appShortcutStore)
                .environmentObject(snippetStore)
        }
        .windowResizability(.contentSize)
    }
}

struct MenuContent: View {
    @EnvironmentObject private var store: CommandStore
    @EnvironmentObject private var appShortcutStore: AppShortcutStore
    @Environment(\.openWindow) private var openWindow

    var body: some View {
        Group {
            if !Accessibility.isTrusted {
                Button("Enable Accessibility Permission…") {
                    Accessibility.openSystemSettings()
                }
                Divider()
            }

            if store.pinnedCommands.isEmpty {
                Button("No pinned commands — choose in Settings…") {
                    openSettingsWindow()
                }
            }
            ForEach(store.pinnedCommands) { command in
                Button(command.name.isEmpty ? "Untitled" : command.name) {
                    CommandApplier.shared.apply(command)
                }
                .keyboardShortcut(for: command)
            }

            if !appShortcutStore.validShortcuts.isEmpty {
                Divider()
                Menu("Shortcuts") {
                    ForEach(appShortcutStore.validShortcuts) { shortcut in
                        Button(shortcut.name.isEmpty ? "Untitled" : shortcut.name) {
                            AppShortcutStore.shared.activate(shortcut.id)
                        }
                        .keyboardShortcut(for: shortcut)
                    }
                }
            }

            Divider()
            Button("Quick Picker…") {
                PickerController.shared.show()
            }
            Button("Settings…") {
                openSettingsWindow()
            }
            Button("Quit WindowPane") {
                NSApp.terminate(nil)
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .openSettings)) { _ in
            openSettingsWindow()
        }
    }

    private func openSettingsWindow() {
        NSApp.activate(ignoringOtherApps: true)
        openWindow(id: "settings")
        DispatchQueue.main.async {
            NSApp.activate(ignoringOtherApps: true)
            NSApp.windows
                .first { $0.title == "WindowPane Settings" }?
                .makeKeyAndOrderFront(nil)
        }
    }
}

private extension View {
    func keyboardShortcut(for command: WindowCommand) -> some View {
        if let shortcut = KeyboardShortcuts.getShortcut(for: HotkeyManager.name(for: command.id)),
           let ks = shortcut.swiftUIShortcut {
            return AnyView(self.keyboardShortcut(ks))
        }
        return AnyView(self)
    }

    func keyboardShortcut(for shortcut: AppShortcut) -> some View {
        if let hotkey = KeyboardShortcuts.getShortcut(for: HotkeyManager.appJumpName(for: shortcut.id)),
           let ks = hotkey.swiftUIShortcut {
            return AnyView(self.keyboardShortcut(ks))
        }
        return AnyView(self)
    }
}
