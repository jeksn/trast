import SwiftUI
import KeyboardShortcuts
import ServiceManagement
import UniformTypeIdentifiers
import WindowPaneCore
import AppKit
import CoreGraphics

struct GeneralSettingsView: View {
    @AppStorage(AppSettings.autoCheckUpdatesKey) private var autoCheckUpdates: Bool = true
    @AppStorage(AppSettings.snippetsEnabledKey) private var snippetsEnabled: Bool = false
    @AppStorage(AppSettings.launcherOpacityKey) private var launcherOpacity: Double = 0.85
    @State private var launchAtLogin = SMAppService.mainApp.status == .enabled
    @State private var isTrusted = Accessibility.isTrusted
    @State private var inputMonitoringGranted = false
    @State private var importError = false

    var body: some View {
        Form {
            Section {
                KeyboardShortcuts.Recorder("Launcher:", name: HotkeyManager.openLauncher)
                Slider(value: $launcherOpacity, in: 0.3...1.0, step: 0.05) {
                    Text("Transparency")
                } minimumValueLabel: {
                    Image(systemName: "circle.dashed")
                } maximumValueLabel: {
                    Image(systemName: "circle.fill")
                }
                .tint(.accentColor)
            } header: {
                Text("Launcher")
            } footer: {
                Text("Press this shortcut anywhere to open the Launcher. Use it to launch apps, run commands, and access all WindowPane features.")
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

            Section {
                Button("Export Configuration…") { exportConfig() }
                Button("Import Configuration…") { importConfig() }
            } header: {
                Text("Backup")
            } footer: {
                Text("Saves or restores all commands and shortcuts to a JSON file. Hotkey bindings are not included — reassign them after importing on a new machine.")
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
                    Text("windowpane://launcher")
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
