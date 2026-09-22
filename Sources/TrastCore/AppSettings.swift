import Foundation

public extension Array {
    subscript(safe index: Int) -> Element? {
        indices.contains(index) ? self[index] : nil
    }
}

public enum AppSettings {
    public static let gapKey = "edgeGap"
    public static let autoCheckUpdatesKey = "autoCheckUpdates"
    public static let clipboardHistorySizeKey = "clipboardHistorySize"
    public static let clipboardAutoClearKey = "clipboardAutoClearSeconds"
    public static let clipboardEnabledKey = "clipboardMonitorEnabled"
    public static let snippetsEnabledKey = "snippetsEnabled"
    public static let hyperKeyEnabledKey = "hyperKeyEnabled"
    public static let hyperSymbolKey = "hyperSymbol"
    public static let launcherOpacityKey = "launcherOpacity"
    public static let launcherClipboardTabKey = "launcherClipboardTab"
    public static let launcherSnippetsTabKey = "launcherSnippetsTab"

    public static var gap: Double {
        UserDefaults.standard.double(forKey: gapKey)
    }

    public static var autoCheckUpdates: Bool {
        UserDefaults.standard.object(forKey: autoCheckUpdatesKey) as? Bool ?? true
    }

    public static var clipboardEnabled: Bool {
        UserDefaults.standard.object(forKey: clipboardEnabledKey) as? Bool ?? true
    }

    public static var snippetsEnabled: Bool {
        UserDefaults.standard.object(forKey: snippetsEnabledKey) as? Bool ?? false
    }

    public static var hyperKeyEnabled: Bool {
        UserDefaults.standard.object(forKey: hyperKeyEnabledKey) as? Bool ?? false
    }

    public static var hyperSymbol: Bool {
        UserDefaults.standard.object(forKey: hyperSymbolKey) as? Bool ?? true
    }

    public static var launcherOpacity: Double {
        let value = UserDefaults.standard.double(forKey: launcherOpacityKey)
        return value > 0 ? value : 0.85
    }

    public static var launcherClipboardTab: Bool {
        UserDefaults.standard.object(forKey: launcherClipboardTabKey) as? Bool ?? true
    }

    public static var launcherSnippetsTab: Bool {
        UserDefaults.standard.object(forKey: launcherSnippetsTabKey) as? Bool ?? true
    }
}
