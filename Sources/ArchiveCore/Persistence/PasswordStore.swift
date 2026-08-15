import Foundation
import Security

public struct PasswordStore: Sendable {
    public static let service = "app.archivist.Archivist.archives"

    public init() {}

    public func save(password: String, for archiveURL: URL) throws {
        let account = archiveURL.standardizedFileURL.path
        let data = Data(password.utf8)
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: Self.service,
            kSecAttrAccount as String: account,
        ]
        SecItemDelete(query as CFDictionary)
        var add = query
        add[kSecValueData as String] = data
        add[kSecAttrAccessible as String] = kSecAttrAccessibleWhenUnlockedThisDeviceOnly
        let status = SecItemAdd(add as CFDictionary, nil)
        guard status == errSecSuccess else {
            throw ArchiveError.backendFailure("Keychain save failed (\(status))")
        }
    }

    public func load(for archiveURL: URL) -> String? {
        let account = archiveURL.standardizedFileURL.path
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: Self.service,
            kSecAttrAccount as String: account,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne,
        ]
        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        guard status == errSecSuccess, let data = result as? Data else { return nil }
        return String(data: data, encoding: .utf8)
    }

    public func delete(for archiveURL: URL) {
        let account = archiveURL.standardizedFileURL.path
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: Self.service,
            kSecAttrAccount as String: account,
        ]
        SecItemDelete(query as CFDictionary)
    }

    public func deleteAll() {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: Self.service,
        ]
        SecItemDelete(query as CFDictionary)
    }

    public static func strength(of password: String) -> Double {
        if password.isEmpty { return 0 }
        var score = 0.0
        score += min(Double(password.count) / 16.0, 0.5)
        let classes = [
            password.rangeOfCharacter(from: .lowercaseLetters) != nil,
            password.rangeOfCharacter(from: .uppercaseLetters) != nil,
            password.rangeOfCharacter(from: .decimalDigits) != nil,
            password.rangeOfCharacter(from: CharacterSet.punctuationCharacters.union(.symbols)) != nil,
        ].filter { $0 }.count
        score += Double(classes) * 0.125
        return min(score, 1)
    }
}
