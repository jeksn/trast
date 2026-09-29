import AppKit
import Foundation
import TrastCore

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
    private static let cacheQueue = DispatchQueue(label: "trast.appscanner.cache")
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

        let name = (bundle?.infoDictionary?["CFBundleDisplayName"] as? String)
            ?? (bundle?.infoDictionary?["CFBundleName"] as? String)
            ?? FileManager.default.displayName(atPath: url.path)

        let icon = downsizedIcon(forFile: url.path)
        return AppChooserItem(
            id: bundleID ?? url.path,
            name: name,
            bundleURL: url,
            bundleIdentifier: bundleID,
            icon: icon
        )
    }

    /// `NSWorkspace.icon` returns the app's full-size icon (up to 1024px).
    /// Rows render at 22pt, so downsample once at scan time instead of
    /// having every row draw scale a large representation on each render.
    private static func downsizedIcon(forFile path: String, size: CGFloat = 64) -> NSImage? {
        let icon = NSWorkspace.shared.icon(forFile: path)
        guard icon.isValid, icon.size.width > size else { return icon }

        guard let rep = NSBitmapImageRep(
            bitmapDataPlanes: nil,
            pixelsWide: Int(size),
            pixelsHigh: Int(size),
            bitsPerSample: 8,
            samplesPerPixel: 4,
            hasAlpha: true,
            isPlanar: false,
            colorSpaceName: .deviceRGB,
            bytesPerRow: 0,
            bitsPerPixel: 0
        ) else { return icon }
        rep.size = NSSize(width: size, height: size)

        NSGraphicsContext.saveGraphicsState()
        guard let context = NSGraphicsContext(bitmapImageRep: rep) else {
            NSGraphicsContext.restoreGraphicsState()
            return icon
        }
        NSGraphicsContext.current = context
        icon.draw(in: NSRect(x: 0, y: 0, width: size, height: size))
        NSGraphicsContext.restoreGraphicsState()

        let image = NSImage(size: NSSize(width: size, height: size))
        image.addRepresentation(rep)
        return image
    }
}
