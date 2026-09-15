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
}
