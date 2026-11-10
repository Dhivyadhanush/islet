import Foundation

/// Local credential file for the Beszel password and Cloudflare Access secret.
///
/// A file is used instead of Keychain because the app is ad-hoc signed: every
/// rebuild changes the signature and Keychain ACLs do not reliably carry over.
/// The file lives under Application Support, is created 0600, and never leaves
/// the Mac.
enum CredentialStore {
    struct Credentials: Codable {
        var password: String = ""
        var accessSecret: String = ""
    }

    private static var directoryURL: URL {
        FileManager.default
            .urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("islet", isDirectory: true)
    }

    private static var fileURL: URL {
        directoryURL.appendingPathComponent("credentials.json")
    }

    /// Pre-1.0 installs wrote to Application Support/lost_Island. Read that file
    /// once, copy it to the new location, and drop the old copy.
    private static var legacyFileURL: URL {
        FileManager.default
            .urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("lost_Island", isDirectory: true)
            .appendingPathComponent("credentials.json")
    }

    static func load() -> Credentials? {
        if let credentials = decode(fileURL) {
            return credentials
        }
        if let credentials = decode(legacyFileURL) {
            write(credentials)
            try? FileManager.default.removeItem(at: legacyFileURL)
            return credentials
        }
        return nil
    }

    static func save(password: String?, accessSecret: String?) {
        var credentials = load() ?? Credentials()
        if let password, !password.isEmpty { credentials.password = password }
        if let accessSecret, !accessSecret.isEmpty { credentials.accessSecret = accessSecret }
        write(credentials)
    }

    static func clear() {
        try? FileManager.default.removeItem(at: fileURL)
        try? FileManager.default.removeItem(at: legacyFileURL)
    }

    private static func decode(_ url: URL) -> Credentials? {
        guard let data = try? Data(contentsOf: url) else { return nil }
        return try? JSONDecoder().decode(Credentials.self, from: data)
    }

    private static func write(_ credentials: Credentials) {
        do {
            try FileManager.default.createDirectory(
                at: directoryURL,
                withIntermediateDirectories: true,
                attributes: [.posixPermissions: 0o700]
            )
            let data = try JSONEncoder().encode(credentials)
            try data.write(to: fileURL, options: [.atomic])
            try FileManager.default.setAttributes(
                [.posixPermissions: 0o600],
                ofItemAtPath: fileURL.path
            )
        } catch {
            // The UI reports connection failures; a storage error here simply
            // leaves the previous credentials in place.
        }
    }
}
