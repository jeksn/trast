import SwiftUI
import KeyboardShortcuts
import ServiceManagement
import UniformTypeIdentifiers
import TrastCore
import AppKit
import CoreGraphics

struct GeneralSettingsView: View {
    @AppStorage(AppSettings.autoCheckUpdatesKey) private var autoCheckUpdates: Bool = true
    @AppStorage(AppSettings.snippetsEnabledKey) private var snippetsEnabled: Bool = false
    @AppStorage(AppSettings.hyperKeyEnabledKey) private var hyperKeyEnabled: Bool = false
    @AppStorage(AppSettings.hyperSymbolKey) private var hyperSymbol: Bool = true
    @AppStorage(AppSettings.launcherOpacityKey) private var launcherOpacity: Double = 0.85
    @AppStorage(AppSettings.launcherClipboardTabKey) private var showClipboardTab: Bool = true
    @AppStorage(AppSettings.launcherSnippetsTabKey) private var showSnippetsTab: Bool = true
    @State private var launchAtLogin = SMAppService.mainApp.status == .enabled
    @State private var isTrusted = Accessibility.isTrusted
    @State private var inputMonitoringGranted = false
    @State private var importError = false

    var body: some View {
        Form {
            Section {
                HotkeyRecorderView("Launcher:", name: HotkeyManager.openLauncher)
                Slider(value: $launcherOpacity, in: 0.3...1.0, step: 0.05) {
                    Text("Transparency")
                } minimumValueLabel: {
                    Image(systemName: "circle.dashed")
                } maximumValueLabel: {
                    Image(systemName: "circle.fill")
                }
                .tint(.accentColor)
                Toggle("Show Clipboard tab", isOn: $showClipboardTab)
                Toggle("Show Snippets tab", isOn: $showSnippetsTab)
            } header: {
                Text("Launcher")
            } footer: {
                Text("Press this shortcut anywhere to open the Launcher. The Clipboard tab shows full clipboard history; the Snippets tab shows available text snippets. Both can be toggled on or off.")
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
                Toggle("Enable hyper key (Caps Lock → ⌃⌥⇧⌘)", isOn: $hyperKeyEnabled)
                    .onChange(of: hyperKeyEnabled) { enabled in
                        if enabled {
                            HyperkeyEngine.shared.start()
                            isTrusted = Accessibility.isTrusted
                            inputMonitoringGranted = CGPreflightListenEventAccess()
                        } else {
                            HyperkeyEngine.shared.stop()
                        }
                    }
                if hyperKeyEnabled && !isTrusted {
                    HStack {
                        Label(
                            "Accessibility permission required",
                            systemImage: "exclamationmark.triangle.fill"
                        )
                        .foregroundStyle(Color.orange)
                        Spacer()
                        Button("Open System Settings") {
                            Accessibility.openSystemSettings()
                        }
                    }
                }
                if hyperKeyEnabled && !inputMonitoringGranted {
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
                Toggle("Show as ✦ in shortcut labels", isOn: $hyperSymbol)
            } header: {
                Text("Hyper Key")
            } footer: {
                Text("Hold Caps Lock to send ⌃⌥⇧⌘ — a modifier combo no other app uses, ideal for Trast hotkeys. A lone Caps Lock tap does nothing. While enabled, Caps Lock is remapped at the driver level (to F18) so the lock state and LED stay off; this reverts when disabled and replaces any Caps Lock remap from System Settings. Requires Accessibility and Input Monitoring. Quit Hyperkey.app or other Caps Lock remappers first — two active remappers on the same key conflict.")
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
                Button("Check for Updates…") {
                    UpdateChecker.checkForUpdates()
                }
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
                    Text("trast://apply?name=Left%20Half")
                    Text("trast://launcher")
                    Text("trast://command?position=center&relativeWidth=0.5&relativeHeight=0.5")
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
            Text("The selected file could not be read as a Trast configuration file.")
        }
    }

    private func exportConfig() {
        guard let data = ConfigPorter.exportData() else { return }
        let panel = NSSavePanel()
        panel.title = "Export Trast Configuration"
        panel.nameFieldStringValue = "trast-config.json"
        panel.allowedContentTypes = [.json]
        if panel.runModal() == .OK, let url = panel.url {
            try? data.write(to: url, options: .atomic)
        }
    }

    private func importConfig() {
        let panel = NSOpenPanel()
        panel.title = "Import Trast Configuration"
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
