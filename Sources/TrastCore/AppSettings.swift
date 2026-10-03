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
    public static let scratchpadTextKey = "scratchpadText"
    public static let launcherOpenViewKey = "launcherOpenView"
    public static let transformOrderKey = "transformOrder"
    public static let transformDisabledKey = "transformDisabled"
    public static let baseCurrencyKey = "baseCurrency"
    public static let preferredUnitsKey = "preferredUnits"
    public static let aiProviderKey = "aiProvider"
    public static let aiAPIKeyKey = "aiAPIKey"

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

    /// Base currency for launcher currency conversions (ISO code).
    public static var baseCurrency: String {
        let value = UserDefaults.standard.string(forKey: baseCurrencyKey) ?? "USD"
        return Calculator.supportedCurrencies.contains(value) ? value : "USD"
    }

    /// "metric" or "imperial" — the system bare-unit launcher queries
    /// convert into.
    public static var preferredUnits: String {
        UserDefaults.standard.string(forKey: preferredUnitsKey) ?? "metric"
    }

    /// True when the launcher should open on the tools/recents view
    /// ("tools", the default — "Full") instead of a bare search bar
    /// ("empty" — "Compact").
    public static var launcherOpensToTools: Bool {
        (UserDefaults.standard.string(forKey: launcherOpenViewKey) ?? "tools") == "tools"
    }

    /// The user's chosen transformation order (Settings → Text Transformer).
    /// Stored rawValues that no longer exist are dropped; transforms missing
    /// from the stored order (added in later releases) append at the end.
    public static var transformOrder: [String] {
        let known = TextTransform.allCases.map(\.rawValue)
        let stored = UserDefaults.standard.stringArray(forKey: transformOrderKey) ?? []
        var result = stored.filter { known.contains($0) }
        result.append(contentsOf: known.filter { !result.contains($0) })
        return result
    }

    public static var disabledTransforms: [String] {
        UserDefaults.standard.stringArray(forKey: transformDisabledKey) ?? []
    }

    /// The enabled transformations in the user's order — the list the Text
    /// Transformer tool shows.
    public static var orderedTransforms: [TextTransform] {
        let order = transformOrder
        let disabled = Set(disabledTransforms)
        var result = order.compactMap { raw -> TextTransform? in
            guard let transform = TextTransform(rawValue: raw), !disabled.contains(raw) else { return nil }
            return transform
        }
        result.append(contentsOf: TextTransform.allCases.filter {
            !order.contains($0.rawValue) && !disabled.contains($0.rawValue)
        })
        return result
    }

    public static func saveTransformOrder(_ rawValues: [String]) {
        UserDefaults.standard.set(rawValues, forKey: transformOrderKey)
    }

    public static func saveDisabledTransforms(_ rawValues: [String]) {
        UserDefaults.standard.set(rawValues, forKey: transformDisabledKey)
    }

    /// BYOK provider id for the (upcoming) AI Chat tool ("openai",
    /// "anthropic", "google", "mistral", "openrouter").
    public static var aiProvider: String {
        UserDefaults.standard.string(forKey: aiProviderKey) ?? "openai"
    }

    /// True when an AI Chat API key has been entered in Settings → Tools.
    public static var hasAIAPIKey: Bool {
        !(UserDefaults.standard.string(forKey: aiAPIKeyKey) ?? "").isEmpty
    }
}
