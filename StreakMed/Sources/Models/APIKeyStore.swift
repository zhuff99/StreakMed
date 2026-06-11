import Foundation
import Security

/// Keychain-backed storage for the user's Claude API key.
/// Replaces the old UserDefaults location ("claudeApiKey"), which stored the
/// key in plaintext inside the preferences plist and device backups. Migrates
/// any existing UserDefaults value on first read, then removes it.
enum APIKeyStore {

    private static let account = "claudeApiKey"
    private static let service = "com.zacharyhuff.StreakMed"
    private static let legacyDefaultsKey = "claudeApiKey"

    static func load() -> String {
        migrateFromUserDefaultsIfNeeded()

        var query = baseQuery
        query[kSecReturnData as String] = true
        query[kSecMatchLimit as String] = kSecMatchLimitOne

        var item: CFTypeRef?
        guard SecItemCopyMatching(query as CFDictionary, &item) == errSecSuccess,
              let data = item as? Data,
              let key = String(data: data, encoding: .utf8)
        else { return "" }
        return key
    }

    static func save(_ key: String) {
        let trimmed = key.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { delete(); return }

        let data = Data(trimmed.utf8)
        var query = baseQuery

        let attributes: [String: Any] = [kSecValueData as String: data]
        let status = SecItemUpdate(query as CFDictionary, attributes as CFDictionary)

        if status == errSecItemNotFound {
            query[kSecValueData as String] = data
            // ThisDeviceOnly: never synced to iCloud Keychain, excluded from backups
            query[kSecAttrAccessible as String] = kSecAttrAccessibleWhenUnlockedThisDeviceOnly
            SecItemAdd(query as CFDictionary, nil)
        }
    }

    static func delete() {
        SecItemDelete(baseQuery as CFDictionary)
    }

    private static var baseQuery: [String: Any] {
        [
            kSecClass as String:       kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
        ]
    }

    private static func migrateFromUserDefaultsIfNeeded() {
        let defaults = UserDefaults.standard
        guard let legacy = defaults.string(forKey: legacyDefaultsKey),
              !legacy.trimmingCharacters(in: .whitespaces).isEmpty
        else { return }
        save(legacy)
        defaults.removeObject(forKey: legacyDefaultsKey)
    }
}
