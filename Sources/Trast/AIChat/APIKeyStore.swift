import Foundation
import Security
import TrastCore

/// The AI Chat API key, stored in the Keychain (not plaintext defaults).
/// Migrates the old UserDefaults value (`AppSettings.aiAPIKeyKey`) once.
enum APIKeyStore {
    private static let service = "com.trast.app"
    private static let account = "ai-api-key"

    /// Reads the key from the Keychain, migrating any legacy UserDefaults
    /// value (and removing it — the defaults copy shouldn't linger).
    static func read() -> String? {
        if let key = readFromKeychain() {
            return key.isEmpty ? nil : key
        }
        // Legacy migration: one-time move from UserDefaults to the Keychain.
        if let legacy = UserDefaults.standard.string(forKey: AppSettings.aiAPIKeyKey), !legacy.isEmpty {
            save(legacy)
            UserDefaults.standard.removeObject(forKey: AppSettings.aiAPIKeyKey)
            return legacy
        }
        return nil
    }

    static func save(_ key: String) {
        let data = Data(key.utf8)
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
        ]
        let attributes: [String: Any] = [kSecValueData as String: data]
        let status = SecItemUpdate(query as CFDictionary, attributes as CFDictionary)
        if status == errSecItemNotFound {
            var addQuery = query
            addQuery[kSecValueData as String] = data
            SecItemAdd(addQuery as CFDictionary, nil)
        }
    }

    static func delete() {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
        ]
        SecItemDelete(query as CFDictionary)
    }

    private static func readFromKeychain() -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne,
        ]
        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        guard status == errSecSuccess, let data = result as? Data else { return nil }
        return String(data: data, encoding: .utf8)
    }
}
