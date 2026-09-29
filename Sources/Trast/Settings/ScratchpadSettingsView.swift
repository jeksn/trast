import SwiftUI
import TrastCore

struct ScratchpadSettingsView: View {
    @AppStorage(AppSettings.scratchpadTextKey) private var scratchpadText = ""

    var body: some View {
        Form {
            Section {
                HotkeyRecorderView("Open Scratchpad:", name: HotkeyManager.openScratchpad)
            } header: {
                Text("Hotkey")
            } footer: {
                Text("Opens the Launcher on the Scratchpad tab; press again to close.")
            }

            Section {
                Button(role: .destructive) {
                    scratchpadText = ""
                } label: {
                    Text("Clear Scratchpad")
                }
                .disabled(scratchpadText.isEmpty)
            } header: {
                Text("Scratchpad")
            } footer: {
                Text("The text is kept in preferences and survives relaunches.")
            }
        }
        .formStyle(.grouped)
    }
}
