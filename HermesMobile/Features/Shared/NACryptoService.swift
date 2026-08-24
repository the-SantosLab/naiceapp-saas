import Foundation
import CryptoKit
import LocalAuthentication

// MARK: - Encrypted Notes
struct NAEncryptedNote: Codable, Identifiable {
    var id = UUID().uuidString
    let encryptedData: Data
    let nonce: Data
    let tag: Data
    let createdAt: Date
    let title: String // Stored unencrypted for search
    var latitude: Double?
    var longitude: Double?
    var locationName: String?
}

// MARK: - Crypto Notes Service
@MainActor
class NACryptoService: ObservableObject {
    static let shared = NACryptoService()

    @Published var notes: [NAEncryptedNote] = []
    @Published var isUnlocked = false
    @Published var authError: String?

    private let keychainKey = "naice_crypto_key"
    private let storageKey = "naice_encrypted_notes"
    private var symmetricKey: SymmetricKey?

    init() {
        loadKey()
        loadNotes()
    }

    private func loadKey() {
        if let keyData = KeychainHelper.load(key: keychainKey) {
            symmetricKey = SymmetricKey(data: keyData)
        } else {
            let newKey = SymmetricKey(size: .bits256)
            let keyData = newKey.withUnsafeBytes { Data($0) }
            KeychainHelper.save(key: keychainKey, data: keyData)
            symmetricKey = newKey
        }
    }

    private func loadNotes() {
        guard let data = UserDefaults.standard.data(forKey: storageKey),
              let decoded = try? JSONDecoder().decode([NAEncryptedNote].self, from: data) else { return }
        notes = decoded
    }

    private func saveNotes() {
        guard let data = try? JSONEncoder().encode(notes) else { return }
        UserDefaults.standard.set(data, forKey: storageKey)
    }

    func authenticate() async -> Bool {
        let context = LAContext()
        var error: NSError?
        guard context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: &error) else {
            authError = "Kein Biometrie-Scanner verfügbar"
            return false
        }
        do {
            try await context.evaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, localizedReason: "Entsperre verschlüsselte Notizen")
            isUnlocked = true
            return true
        } catch {
            authError = error.localizedDescription
            return false
        }
    }

    func encryptNote(title: String, content: String, latitude: Double? = nil, longitude: Double? = nil, locationName: String? = nil) {
        guard let key = symmetricKey else { return }
        guard let data = content.data(using: .utf8) else { return }

        let sealedBox = try! AES.GCM.seal(data, using: key)

        let note = NAEncryptedNote(
            encryptedData: sealedBox.ciphertext,
            nonce: sealedBox.nonce.withUnsafeBytes { Data($0) },
            tag: sealedBox.tag,
            createdAt: Date(),
            title: title,
            latitude: latitude,
            longitude: longitude,
            locationName: locationName
        )
        notes.insert(note, at: 0)
        saveNotes()
    }

    func decryptNote(_ note: NAEncryptedNote) -> String? {
        guard let key = symmetricKey else { return nil }
        guard let nonce = try? AES.GCM.Nonce(data: note.nonce) else { return nil }
        let sealedBox = try! AES.GCM.SealedBox(nonce: nonce, ciphertext: note.encryptedData, tag: note.tag)
        guard let data = try? AES.GCM.open(sealedBox, using: key) else { return nil }
        return String(data: data, encoding: .utf8)
    }

    func deleteNote(_ id: String) {
        notes.removeAll { $0.id == id }
        saveNotes()
    }
}

// MARK: - Keychain Helper
struct KeychainHelper {
    static func save(key: String, data: Data) {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: key,
            kSecValueData as String: data,
            kSecAttrAccessible as String: kSecAttrAccessibleWhenUnlockedThisDeviceOnly
        ]
        SecItemDelete(query as CFDictionary)
        SecItemAdd(query as CFDictionary, nil)
    }

    static func load(key: String) -> Data? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: key,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]
        var item: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &item)
        guard status == errSecSuccess else { return nil }
        return item as? Data
    }
}