import SwiftUI
import KeyboardShortcuts
import ServiceManagement
import UniformTypeIdentifiers
import WindowPaneCore
import AppKit
import CoreGraphics

struct GeneralSettingsView: View {
    @AppStorage(AppSettings.gapKey) private var gap: Double = 0
    @AppStorage(AppSettings.autoCheckUpdatesKey) private var autoCheckUpdates: Bool = true
    @AppStorage(AppSettings.snippetsEnabledKey) private var snippetsEnabled: Bool = false
    @State private var launchAtLogin = SMAppService.mainApp.status == .enabled
    @State private var isTrusted = Accessibility.isTrusted
    @State private var inputMonitoringGranted = false
    @State private var importError = false

    var body: some View {
        Form {
            Section("Window Sizing") {
                HStack {
                    Text("Edge gap")
                    Spacer()
                    TextField("Gap", value: $gap, format: .number)
                        .frame(width: 76)
                        .multilineTextAlignment(.trailing)
                    Text("px")
                        .foregroundStyle(.secondary)
                }
            }
            Section("Hotkeys") {
                KeyboardShortcuts.Recorder("Quick Picker:", name: HotkeyManager.openPicker)
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
                Text("Parameterless actions — they keep the window's size and only change its position. Also available in the Quick Picker.")
            }
            Section {
                Button("Export Configuration…") { exportConfig() }
                Button("Import Configuration…") { importConfig() }
            } header: {
                Text("Backup")
            } footer: {
                Text("Saves or restores all commands and shortcuts to a JSON file. Hotkey bindings are not included — reassign them after importing on a new machine.")
            }
            Section {
                Toggle("Enable snippet expansion", isOn: $snippetsEnabled)
                    .onChange(of: snippetsEnabled) { enabled in
                        if enabled {
                            SnippetExpander.shared.start()
                            inputMonitoringGranted = CGPreflightListenEventAccess()
                        } else {
                            SnippetExpander.shared.stop()
                        }
                    }
                if snippetsEnabled && !inputMonitoringGranted {
                    HStack {
                        Label(
                            "Input Monitoring permission required",
                            systemImage: "exclamationmark.triangle.fill"
                        )
                        .foregroundStyle(Color.orange)
                        Spacer()
                        Button("Open System Settings") {
                            Accessibility.openSystemSettings()
                        }
                    }
                }
            } header: {
                Text("Snippets")
            } footer: {
                Text("Type a snippet keyword anywhere to expand it. Requires Input Monitoring permission (prompted on first enable) and Accessibility for text injection.")
            }
            Section("System") {
                LabeledContent("Version", value: UpdateChecker.currentVersion)
                Toggle("Launch at login", isOn: $launchAtLogin)
                    .onChange(of: launchAtLogin) { enabled in
                        do {
                            if enabled {
                                try SMAppService.mainApp.register()
                            } else {
                                try SMAppService.mainApp.unregister()
                            }
                        } catch {
                            launchAtLogin = SMAppService.mainApp.status == .enabled
                        }
                    }
                Toggle("Check for updates on launch", isOn: $autoCheckUpdates)
                HStack {
                    Label(
                        isTrusted ? "Accessibility granted" : "Accessibility permission required",
                        systemImage: isTrusted ? "checkmark.circle.fill" : "exclamationmark.triangle.fill"
                    )
                    .foregroundStyle(isTrusted ? Color.green : Color.orange)
                    Spacer()
                    Button("Refresh") { isTrusted = Accessibility.isTrusted }
                    Button("Open System Settings") {
                        Accessibility.openSystemSettings()
                    }
                }
            }
            Section("URL Scheme") {
                VStack(alignment: .leading, spacing: 6) {
                    Text("windowpane://apply?name=Left%20Half")
                    Text("windowpane://picker")
                    Text("windowpane://command?position=center&relativeWidth=0.5&relativeHeight=0.5")
                }
                .font(.system(size: 12, design: .monospaced))
                .foregroundStyle(.secondary)
                .textSelection(.enabled)
            }
        }
        .formStyle(.grouped)
        .onAppear {
            isTrusted = Accessibility.isTrusted
            inputMonitoringGranted = CGPreflightListenEventAccess()
        }
        .alert("Import Failed", isPresented: $importError) {
            Button("OK") { }
        } message: {
            Text("The selected file could not be read as a WindowPane configuration file.")
        }
    }

    private func exportConfig() {
        guard let data = ConfigPorter.exportData() else { return }
        let panel = NSSavePanel()
        panel.title = "Export WindowPane Configuration"
        panel.nameFieldStringValue = "windowpane-config.json"
        panel.allowedContentTypes = [.json]
        if panel.runModal() == .OK, let url = panel.url {
            try? data.write(to: url, options: .atomic)
        }
    }

    private func importConfig() {
        let panel = NSOpenPanel()
        panel.title = "Import WindowPane Configuration"
        panel.allowedContentTypes = [.json]
        panel.allowsMultipleSelection = false
        if panel.runModal() == .OK, let url = panel.url {
            guard let data = try? Data(contentsOf: url) else {
                importError = true
                return
            }
            if !ConfigPorter.importData(data) {
                importError = true
            }
        }
    }
}
