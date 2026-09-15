import AppKit
import Foundation
import WindowPaneCore

struct AppChooserItem: Identifiable, Hashable {
    let id: String
    let name: String
    let bundleURL: URL
    let bundleIdentifier: String?
    let icon: NSImage?

    var appShortcut: AppShortcut {
        AppShortcut(
            name: name,
            kind: .app,
            bundleIdentifier: bundleIdentifier,
            bundleURL: bundleURL
        )
    }
}

enum AppScanner {
    private static let cacheQueue = DispatchQueue(label: "windowpane.appscanner.cache")
    private static var cached: [AppChooserItem] = []

    static func cachedApps() -> [AppChooserItem] {
        cacheQueue.sync { cached }
    }

    static func refresh() {
        DispatchQueue.global(qos: .utility).async {
            let apps = installedApps()
            cacheQueue.sync { cached = apps }
        }
    }

    static func installedApps() -> [AppChooserItem] {
        var seen = Set<String>()
        var items: [AppChooserItem] = []

        let directories = [
            URL(fileURLWithPath: "/Applications"),
            URL(fileURLWithPath: "/System/Applications"),
            URL(fileURLWithPath: "/System/Library/CoreServices/Applications"),
            FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("Applications"),
        ].filter { FileManager.default.fileExists(atPath: $0.path) }

        for directory in directories {
            guard let enumerator = FileManager.default.enumerator(
                at: directory,
                includingPropertiesForKeys: nil,
                options: [.skipsPackageDescendants, .skipsHiddenFiles],
                errorHandler: nil
            ) else { continue }

            for case let fileURL as URL in enumerator {
                guard fileURL.pathExtension == "app" else { continue }
                let path = fileURL.path
                guard !seen.contains(path) else { continue }
                seen.insert(path)
                if let item = makeItem(for: fileURL) {
                    items.append(item)
                }
            }
        }

        for app in NSWorkspace.shared.runningApplications where app.activationPolicy == .regular {
            guard let url = app.bundleURL, !seen.contains(url.path) else { continue }
            seen.insert(url.path)
            if let item = makeItem(for: url) {
                items.append(item)
            }
        }

        return items.sorted {
            $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending
        }
    }

    private static func makeItem(for url: URL) -> AppChooserItem? {
        let bundle = Bundle(url: url)
        let bundleID = bundle?.bundleIdentifier

        if let info = bundle?.infoDictionary {
            if (info["LSUIElement"] as? Bool) == true {
                return nil
            }
        }

        let name = (bundle?.infoDictionary?["CFBundleDisplayName"] as? String)
            ?? (bundle?.infoDictionary?["CFBundleName"] as? String)
            ?? FileManager.default.displayName(atPath: url.path)

        let icon = NSWorkspace.shared.icon(forFile: url.path)
        return AppChooserItem(
            id: bundleID ?? url.path,
            name: name,
            bundleURL: url,
            bundleIdentifier: bundleID,
            icon: icon
        )
    }
}
