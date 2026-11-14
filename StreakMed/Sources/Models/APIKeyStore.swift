import Foundation
import Security

/// Prescription scanning (user-supplied Claude API key) was removed in 1.2.1.
/// This only cleans up: anyone who entered a key had it stored in the
/// Keychain (and, before 1.2, UserDefaults). A secret for a feature that no
/// longer exists shouldn't linger on the device. Full scanner implementation
/// is in git history (PrescriptionScanner.swift, before 1.2.1).
enum APIKeyStore {
    static func purgeRemovedScannerData() {
        let defaults = UserDefaults.standard
        guard !defaults.bool(forKey: "scannerDataPurged") else { return }
        SecItemDelete([
            kSecClass as String:       kSecClassGenericPassword,
            kSecAttrService as String: "com.zacharyhuff.StreakMed",
            kSecAttrAccount as String: "claudeApiKey",
        ] as CFDictionary)
        defaults.removeObject(forKey: "claudeApiKey")
        defaults.removeObject(forKey: "hasAcknowledgedScanPrivacy")
        defaults.set(true, forKey: "scannerDataPurged")
    }
}
