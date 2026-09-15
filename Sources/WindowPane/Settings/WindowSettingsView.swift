import SwiftUI
import KeyboardShortcuts
import WindowPaneCore

struct WindowSettingsView: View {
    @AppStorage(AppSettings.gapKey) private var gap: Double = 0

    var body: some View {
        Form {
            Section("Hotkeys") {
                KeyboardShortcuts.Recorder("Clipboard History:", name: HotkeyManager.openClipboard)
                KeyboardShortcuts.Recorder("Restore Previous Size:", name: HotkeyManager.restore)
                KeyboardShortcuts.Recorder("Next Window:", name: HotkeyManager.nextWindow)
            }

            Section {
                ForEach(WindowAction.all) { action in
                    KeyboardShortcuts.Recorder("\(action.name):", name: HotkeyManager.actionName(action.id))
                }
            } header: {
                Text("Actions")
            } footer: {
                Text("Parameterless actions — they keep the window's size and only change its position. Also available in the Launcher.")
            }

            Section {
                Picker("Edge gap", selection: $gap) {
                    Text("Small").tag(10.0)
                    Text("Medium").tag(20.0)
                    Text("Large").tag(40.0)
                    Text("Extra Large").tag(60.0)
                }
                .pickerStyle(.segmented)
            } header: {
                Text("Sizing")
            } footer: {
                Text("Spacing between windows and screen edges.")
            }
        }
        .formStyle(.grouped)
    }
}
