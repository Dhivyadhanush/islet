import Foundation
import Security

/// Small generic-password store for the Beszel password and Cloudflare Access
/// service secret.
///
/// The item's ACL trusts the app bundle path, not just the current ad-hoc
/// signature, so rebuilding the app at the same path can still read and update
/// the credentials.
enum Keychain {
    private static let service = "dev.dhanuz.islet"

    static func set(_ value: String, account: String) {
        guard !value.isEmpty else {
            delete(account: account)
            return
        }

        let data = Data(value.utf8)
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
        ]

        var update: [String: Any] = [
            kSecValueData as String: data,
        ]

        let status = SecItemUpdate(query as CFDictionary, update as CFDictionary)
        if status == errSecItemNotFound {
            var add = query
            add[kSecValueData as String] = data
            if let access = accessObject() {
                add[kSecAttrAccess as String] = access
            } else {
                add[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlock
            }
            SecItemAdd(add as CFDictionary, nil)
        } else if status != errSecSuccess {
            // The existing item may be bound to an older signature. Try a
            // fresh add; if the item is still there, leave it alone.
            var add = query
            add[kSecValueData as String] = data
            if let access = accessObject() {
                add[kSecAttrAccess as String] = access
            }
            SecItemAdd(add as CFDictionary, nil)
        }
    }

    static func get(account: String) -> String? {
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

    static func delete(account: String) {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
        ]
        SecItemDelete(query as CFDictionary)
    }

    /// ACL that trusts this app's bundle path. A rebuilt app at the same path
    /// can read the item without a signature-specific prompt.
    private static func accessObject() -> SecAccess? {
        var trusted: SecTrustedApplication?
        let trustedStatus = SecTrustedApplicationCreateFromPath(
            Bundle.main.bundlePath,
            &trusted
        )
        guard trustedStatus == errSecSuccess, let trusted else { return nil }

        var access: SecAccess?
        let accessStatus = SecAccessCreate(
            service as CFString,
            [trusted] as CFArray,
            &access
        )
        guard accessStatus == errSecSuccess else { return nil }
        return access
    }
}
