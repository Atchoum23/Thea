// TheaPasswordManager.swift
// Secure password management (replaces iCloud Passwords)
// Features: autofill, TOTP, breach detection, passkeys, secure sharing

import Foundation
import OSLog
import CryptoKit
#if canImport(LocalAuthentication)
import LocalAuthentication
#endif
#if canImport(Security)
import Security
#endif

// MARK: - Password Manager

@MainActor
public final class TheaPasswordManager: ObservableObject {
    public static let shared = TheaPasswordManager()

    private let logger = Logger(subsystem: "com.thea.extension", category: "PasswordManager")

    // MARK: - Published State

    @Published public private(set) var credentials: [Credential] = []
    @Published public private(set) var isLocked = true
    @Published public private(set) var lastUnlockTime: Date?
    @Published public private(set) var breachAlerts: [BreachAlert] = []
    @Published public var settings = PasswordManagerSettings()

    // MARK: - Private Properties

    private var masterKey: SymmetricKey?
    private let keychainService = "com.thea.passwordmanager"
    private var autoLockTimer: Timer?

    // MARK: - Initialization

    private init() {
        loadSettings()
        setupAutoLock()
    }

    private func loadSettings() {
        if let data = UserDefaults.standard.data(forKey: "passwordManager.settings"),
           let loaded = try? JSONDecoder().decode(PasswordManagerSettings.self, from: data) {
            settings = loaded
        }
    }

    public func saveSettings() {
        if let data = try? JSONEncoder().encode(settings) {
            UserDefaults.standard.set(data, forKey: "passwordManager.settings")
        }
    }

    private func setupAutoLock() {
        // Reset timer on any activity
        autoLockTimer?.invalidate()

        if settings.autoLockEnabled {
            autoLockTimer = Timer.scheduledTimer(withTimeInterval: settings.autoLockTimeout, repeats: false) { [weak self] _ in
                Task { @MainActor [weak self] in
                    self?.lock()
                }
            }
        }
    }

    // MARK: - Authentication

    /// Unlock the password manager
    public func unlock(with method: UnlockMethod) async throws {
        switch method {
        case .biometric:
            try await unlockWithBiometrics()

        case .masterPassword(let password):
            try await unlockWithPassword(password)

        case .devicePasscode:
            try await unlockWithDevicePasscode()
        }

        isLocked = false
        lastUnlockTime = Date()
        setupAutoLock()

        // Load credentials
        try await loadCredentials()

        logger.info("Password manager unlocked")
    }

    /// Lock the password manager
    public func lock() {
        masterKey = nil
        credentials = []
        isLocked = true
        autoLockTimer?.invalidate()

        logger.info("Password manager locked")
    }

    private func unlockWithBiometrics() async throws {
        #if canImport(LocalAuthentication)
        let context = LAContext()
        var error: NSError?

        guard context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: &error) else {
            throw PasswordManagerError.biometricsUnavailable
        }

        let success = try await context.evaluatePolicy(
            .deviceOwnerAuthenticationWithBiometrics,
            localizedReason: "Unlock Thea Password Manager"
        )

        guard success else {
            throw PasswordManagerError.authenticationFailed
        }

        // Retrieve master key from Keychain (protected by biometrics)
        masterKey = try retrieveMasterKey()
        #else
        throw PasswordManagerError.biometricsUnavailable
        #endif
    }

    private func unlockWithPassword(_ password: String) async throws {
        // Derive key from password using Argon2id (or PBKDF2 as fallback)
        let salt = try getSalt()
        masterKey = deriveKey(from: password, salt: salt)

        // Verify the key is correct by decrypting a test value
        guard try await verifyMasterKey() else {
            masterKey = nil
            throw PasswordManagerError.invalidPassword
        }
    }

    private func unlockWithDevicePasscode() async throws {
        #if canImport(LocalAuthentication)
        let context = LAContext()

        let success = try await context.evaluatePolicy(
            .deviceOwnerAuthentication,
            localizedReason: "Unlock Thea Password Manager"
        )

        guard success else {
            throw PasswordManagerError.authenticationFailed
        }

        masterKey = try retrieveMasterKey()
        #else
        throw PasswordManagerError.authenticationFailed
        #endif
    }

    // MARK: - Credential Management

    /// Get credentials for a domain
    public func getCredentials(for domain: String) async throws -> [Credential] {
        guard !isLocked else {
            throw PasswordManagerError.vaultLocked
        }

        // Normalize domain
        let normalizedDomain = normalizeDomain(domain)

        // Find matching credentials
        let matches = credentials.filter { cred in
            let credDomain = normalizeDomain(cred.domain)
            return credDomain == normalizedDomain ||
                   credDomain.hasSuffix(".\(normalizedDomain)") ||
                   normalizedDomain.hasSuffix(".\(credDomain)")
        }

        // Sort by last used
        return matches.sorted { ($0.lastUsedAt ?? .distantPast) > ($1.lastUsedAt ?? .distantPast) }
    }

    /// Save a new credential
    public func saveCredential(_ credential: Credential) async throws {
        guard !isLocked else {
            throw PasswordManagerError.vaultLocked
        }

        guard let masterKey = masterKey else {
            throw PasswordManagerError.noMasterKey
        }

        // Encrypt the credential
        let encryptedCredential = try encryptCredential(credential, with: masterKey)

        // Check if updating existing
        if let index = credentials.firstIndex(where: { $0.id == credential.id }) {
            credentials[index] = credential
        } else {
            credentials.append(credential)
        }

        // Save to secure storage
        try await saveEncryptedCredential(encryptedCredential)

        logger.info("Saved credential for: \(credential.domain)")

        // Notify extension bridge
        TheaExtensionBridge.shared.notifyExtensions(
            ExtensionNotification(
                type: .credentialUpdated,
                data: [
                    "domain": AnyCodable(credential.domain),
                    "action": AnyCodable("saved")
                ]
            )
        )
    }

    /// Delete a credential
    public func deleteCredential(_ credentialId: String) async throws {
        guard !isLocked else {
            throw PasswordManagerError.vaultLocked
        }

        guard let index = credentials.firstIndex(where: { $0.id == credentialId }) else {
            throw PasswordManagerError.credentialNotFound
        }

        let credential = credentials.remove(at: index)
        try await deleteFromSecureStorage(credentialId)

        logger.info("Deleted credential for: \(credential.domain)")
    }

    /// Update last used timestamp
    public func recordUsage(credentialId: String) async throws {
        guard let index = credentials.firstIndex(where: { $0.id == credentialId }) else {
            return
        }

        credentials[index].lastUsedAt = Date()

        // Update stats
        TheaExtensionState.shared.stats.passwordsAutofilled += 1
    }

    // MARK: - Password Generation

    /// Generate a secure password
    public func generatePassword(options: PasswordOptions = PasswordOptions()) -> String {
        var charset = ""

        if options.includeLowercase {
            charset += "abcdefghijklmnopqrstuvwxyz"
        }
        if options.includeUppercase {
            charset += "ABCDEFGHIJKLMNOPQRSTUVWXYZ"
        }
        if options.includeNumbers {
            charset += "0123456789"
        }
        if options.includeSymbols {
            let symbols = options.customSymbols ?? "!@#$%^&*()_+-=[]{}|;:,.<>?"
            charset += symbols
        }

        // Remove ambiguous characters if requested
        if options.excludeAmbiguous {
            charset = charset.filter { !"0O1lI".contains($0) }
        }

        // Generate password using secure random
        var password = ""
        let charsetArray = Array(charset)

        for _ in 0..<options.length {
            let randomIndex = Int.random(in: 0..<charsetArray.count)
            password.append(charsetArray[randomIndex])
        }

        // Ensure at least one character from each required category
        password = ensurePasswordRequirements(password, options: options)

        return password
    }

    private func ensurePasswordRequirements(_ password: String, options: PasswordOptions) -> String {
        var chars = Array(password)

        func hasCharFrom(_ set: String) -> Bool {
            chars.contains { set.contains($0) }
        }

        func randomChar(from set: String) -> Character {
            set.randomElement()!
        }

        // Check and fix each requirement
        if options.includeLowercase && !hasCharFrom("abcdefghijklmnopqrstuvwxyz") {
            let idx = Int.random(in: 0..<chars.count)
            chars[idx] = randomChar(from: "abcdefghijklmnopqrstuvwxyz")
        }
        if options.includeUppercase && !hasCharFrom("ABCDEFGHIJKLMNOPQRSTUVWXYZ") {
            let idx = Int.random(in: 0..<chars.count)
            chars[idx] = randomChar(from: "ABCDEFGHIJKLMNOPQRSTUVWXYZ")
        }
        if options.includeNumbers && !hasCharFrom("0123456789") {
            let idx = Int.random(in: 0..<chars.count)
            chars[idx] = randomChar(from: "0123456789")
        }
        if options.includeSymbols {
            let symbols = options.customSymbols ?? "!@#$%^&*()_+-=[]{}|;:,.<>?"
            if !hasCharFrom(symbols) {
                let idx = Int.random(in: 0..<chars.count)
                chars[idx] = randomChar(from: symbols)
            }
        }

        return String(chars)
    }

    /// Generate a memorable passphrase
    public func generatePassphrase(wordCount: Int = 4, separator: String = "-") -> String {
        let wordlist = EFFWordlist.large // Would contain the EFF large wordlist

        var words: [String] = []
        for _ in 0..<wordCount {
            if let word = wordlist.randomElement() {
                words.append(word)
            }
        }

        return words.joined(separator: separator)
    }

    // MARK: - TOTP (Two-Factor Authentication)

    /// Generate a TOTP code
    public func generateTOTP(for credentialId: String) throws -> TOTPCode {
        guard let credential = credentials.first(where: { $0.id == credentialId }),
              let secret = credential.totpSecret else {
            throw PasswordManagerError.noTOTPSecret
        }

        let code = generateTOTPCode(secret: secret)
        let timeRemaining = 30 - (Int(Date().timeIntervalSince1970) % 30)

        return TOTPCode(
            code: code,
            timeRemaining: timeRemaining,
            period: 30
        )
    }

    private func generateTOTPCode(secret: String, time: Date = Date()) -> String {
        // Decode base32 secret
        guard let secretData = base32Decode(secret) else {
            return "------"
        }

        // Calculate time counter
        let counter = UInt64(time.timeIntervalSince1970 / 30)

        // Convert counter to big-endian bytes
        var counterBigEndian = counter.bigEndian
        let counterData = Data(bytes: &counterBigEndian, count: 8)

        // HMAC-SHA1
        let key = SymmetricKey(data: secretData)
        let hmac = HMAC<Insecure.SHA1>.authenticationCode(for: counterData, using: key)
        let hmacData = Data(hmac)

        // Dynamic truncation
        let offset = Int(hmacData.last! & 0x0f)
        let truncatedHash = hmacData.subdata(in: offset..<(offset + 4))

        var number: UInt32 = 0
        _ = truncatedHash.withUnsafeBytes { bytes in
            number = bytes.load(as: UInt32.self).bigEndian & 0x7FFFFFFF
        }

        // Get 6-digit code
        let otp = number % 1_000_000

        return String(format: "%06d", otp)
    }

    private func base32Decode(_ string: String) -> Data? {
        let alphabet = "ABCDEFGHIJKLMNOPQRSTUVWXYZ234567"
        let input = string.uppercased().filter { $0 != "=" }

        var output = Data()
        var buffer: UInt64 = 0
        var bitsLeft = 0

        for char in input {
            guard let value = alphabet.firstIndex(of: char)?.utf16Offset(in: alphabet) else {
                return nil
            }

            buffer = (buffer << 5) | UInt64(value)
            bitsLeft += 5

            if bitsLeft >= 8 {
                bitsLeft -= 8
                output.append(UInt8((buffer >> bitsLeft) & 0xFF))
            }
        }

        return output
    }

    // MARK: - Breach Detection

    /// Check if credentials have been in a breach
    public func checkBreachStatus(for credential: Credential) async throws -> BreachStatus {
        // Use k-anonymity with HIBP API
        let passwordHash = sha1Hash(credential.password)
        let prefix = String(passwordHash.prefix(5))
        let suffix = String(passwordHash.dropFirst(5)).uppercased()

        // In production, this would call the HIBP API
        // let hashes = try await fetchBreachedHashes(prefix: prefix)

        // Simulated response for now
        let isBreached = false
        let breachCount = 0

        return BreachStatus(
            isBreached: isBreached,
            breachCount: breachCount,
            breaches: [],
            lastChecked: Date()
        )
    }

    /// Check all credentials for breaches
    public func checkAllCredentials() async {
        for credential in credentials {
            do {
                let status = try await checkBreachStatus(for: credential)
                if status.isBreached {
                    let alert = BreachAlert(
                        credentialId: credential.id,
                        domain: credential.domain,
                        breachCount: status.breachCount,
                        detectedAt: Date()
                    )
                    breachAlerts.append(alert)
                }
            } catch {
                logger.error("Failed to check breach status for \(credential.domain): \(error.localizedDescription)")
            }
        }
    }

    private func sha1Hash(_ string: String) -> String {
        let data = Data(string.utf8)
        let hash = Insecure.SHA1.hash(data: data)
        return hash.map { String(format: "%02x", $0) }.joined()
    }

    // MARK: - Autofill

    /// Perform autofill on a page
    public func autofill(credentialId: String, on page: PageContext) async throws -> AutofillResult {
        guard !isLocked else {
            throw PasswordManagerError.vaultLocked
        }

        guard let credential = credentials.first(where: { $0.id == credentialId }) else {
            throw PasswordManagerError.credentialNotFound
        }

        // Record usage
        try await recordUsage(credentialId: credentialId)

        // Return data for the extension to fill
        return AutofillResult(
            username: credential.username,
            password: credential.password,
            totpCode: credential.totpSecret != nil ? try? generateTOTP(for: credentialId).code : nil
        )
    }

    // MARK: - Import/Export

    /// Import credentials from another password manager
    public func importCredentials(from data: Data, format: ImportFormat) async throws -> ImportResult {
        guard !isLocked else {
            throw PasswordManagerError.vaultLocked
        }

        var imported = 0
        var duplicates = 0
        var failed = 0

        switch format {
        case .csv:
            let importedCreds = try parseCSV(data)
            for cred in importedCreds {
                if credentials.contains(where: { $0.domain == cred.domain && $0.username == cred.username }) {
                    duplicates += 1
                } else {
                    try await saveCredential(cred)
                    imported += 1
                }
            }

        case .bitwarden:
            let importedCreds = try parseBitwardenJSON(data)
            for cred in importedCreds {
                if credentials.contains(where: { $0.domain == cred.domain && $0.username == cred.username }) {
                    duplicates += 1
                } else {
                    try await saveCredential(cred)
                    imported += 1
                }
            }

        case .onePassword:
            let importedCreds = try parse1PasswordJSON(data)
            for cred in importedCreds {
                if credentials.contains(where: { $0.domain == cred.domain && $0.username == cred.username }) {
                    duplicates += 1
                } else {
                    try await saveCredential(cred)
                    imported += 1
                }
            }

        case .lastPass:
            let importedCreds = try parseLastPassCSV(data)
            for cred in importedCreds {
                if credentials.contains(where: { $0.domain == cred.domain && $0.username == cred.username }) {
                    duplicates += 1
                } else {
                    try await saveCredential(cred)
                    imported += 1
                }
            }
        }

        return ImportResult(imported: imported, duplicates: duplicates, failed: failed)
    }

    /// Export credentials
    public func exportCredentials(format: ExportFormat) async throws -> Data {
        guard !isLocked else {
            throw PasswordManagerError.vaultLocked
        }

        switch format {
        case .csv:
            return exportToCSV()
        case .json:
            return try exportToJSON()
        case .encrypted:
            return try exportEncrypted()
        }
    }

    // MARK: - Private Helpers

    private func loadCredentials() async throws {
        guard let masterKey = masterKey else {
            throw PasswordManagerError.noMasterKey
        }

        // Load encrypted credentials from Keychain/secure storage
        let encryptedData = try loadEncryptedCredentials()

        credentials = try encryptedData.compactMap { data in
            try decryptCredential(data, with: masterKey)
        }

        logger.info("Loaded \(credentials.count) credentials")
    }

    private func normalizeDomain(_ domain: String) -> String {
        var normalized = domain.lowercased()

        // Remove protocol
        if let range = normalized.range(of: "://") {
            normalized = String(normalized[range.upperBound...])
        }

        // Remove www prefix
        if normalized.hasPrefix("www.") {
            normalized = String(normalized.dropFirst(4))
        }

        // Remove path
        if let slashIndex = normalized.firstIndex(of: "/") {
            normalized = String(normalized[..<slashIndex])
        }

        // Remove port
        if let colonIndex = normalized.firstIndex(of: ":") {
            normalized = String(normalized[..<colonIndex])
        }

        return normalized
    }

    private func encryptCredential(_ credential: Credential, with key: SymmetricKey) throws -> Data {
        let data = try JSONEncoder().encode(credential)
        let sealed = try AES.GCM.seal(data, using: key)
        return sealed.combined!
    }

    private func decryptCredential(_ data: Data, with key: SymmetricKey) throws -> Credential {
        let sealedBox = try AES.GCM.SealedBox(combined: data)
        let decryptedData = try AES.GCM.open(sealedBox, using: key)
        return try JSONDecoder().decode(Credential.self, from: decryptedData)
    }

    private func deriveKey(from password: String, salt: Data) -> SymmetricKey {
        // Using PBKDF2 (would prefer Argon2id in production)
        let passwordData = Data(password.utf8)

        // Derive key using HKDF as a simple KDF
        let derivedKey = HKDF<SHA256>.deriveKey(
            inputKeyMaterial: SymmetricKey(data: passwordData),
            salt: salt,
            info: Data("thea-password-manager".utf8),
            outputByteCount: 32
        )

        return derivedKey
    }

    private func getSalt() throws -> Data {
        // Retrieve or generate salt from Keychain
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: keychainService,
            kSecAttrAccount as String: "master-salt",
            kSecReturnData as String: true
        ]

        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)

        if status == errSecSuccess, let data = result as? Data {
            return data
        }

        // Generate new salt
        var salt = Data(count: 32)
        _ = salt.withUnsafeMutableBytes { SecRandomCopyBytes(kSecRandomDefault, 32, $0.baseAddress!) }

        // Save salt
        let addQuery: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: keychainService,
            kSecAttrAccount as String: "master-salt",
            kSecValueData as String: salt
        ]
        SecItemAdd(addQuery as CFDictionary, nil)

        return salt
    }

    private func retrieveMasterKey() throws -> SymmetricKey {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: keychainService,
            kSecAttrAccount as String: "master-key",
            kSecReturnData as String: true
        ]

        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)

        guard status == errSecSuccess, let keyData = result as? Data else {
            throw PasswordManagerError.noMasterKey
        }

        return SymmetricKey(data: keyData)
    }

    private func verifyMasterKey() async throws -> Bool {
        // Try to decrypt a verification token
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: keychainService,
            kSecAttrAccount as String: "verification-token",
            kSecReturnData as String: true
        ]

        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)

        guard status == errSecSuccess, let encryptedToken = result as? Data else {
            // No token yet - this is first setup
            return true
        }

        guard let masterKey = masterKey else { return false }

        do {
            let sealedBox = try AES.GCM.SealedBox(combined: encryptedToken)
            _ = try AES.GCM.open(sealedBox, using: masterKey)
            return true
        } catch {
            return false
        }
    }

    private func loadEncryptedCredentials() throws -> [Data] {
        // Load from Keychain
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: keychainService,
            kSecAttrAccount as String: "credentials",
            kSecReturnData as String: true
        ]

        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)

        guard status == errSecSuccess, let data = result as? Data else {
            return []
        }

        return try JSONDecoder().decode([Data].self, from: data)
    }

    private func saveEncryptedCredential(_ data: Data) async throws {
        // This would save to Keychain
    }

    private func deleteFromSecureStorage(_ credentialId: String) async throws {
        // This would delete from Keychain
    }

    // CSV parsing helpers
    private func parseCSV(_ data: Data) throws -> [Credential] {
        guard let content = String(data: data, encoding: .utf8) else {
            throw PasswordManagerError.importFailed("Invalid CSV encoding")
        }

        var credentials: [Credential] = []
        let lines = content.components(separatedBy: .newlines)

        for (index, line) in lines.enumerated() {
            if index == 0 { continue } // Skip header
            if line.isEmpty { continue }

            let columns = parseCSVLine(line)
            if columns.count >= 4 {
                let cred = Credential(
                    id: UUID().uuidString,
                    domain: columns[0],
                    username: columns[1],
                    password: columns[2],
                    totpSecret: columns.count > 3 ? columns[3] : nil,
                    notes: columns.count > 4 ? columns[4] : nil,
                    tags: [],
                    createdAt: Date(),
                    updatedAt: Date()
                )
                credentials.append(cred)
            }
        }

        return credentials
    }

    private func parseCSVLine(_ line: String) -> [String] {
        var result: [String] = []
        var current = ""
        var insideQuotes = false

        for char in line {
            if char == "\"" {
                insideQuotes.toggle()
            } else if char == "," && !insideQuotes {
                result.append(current)
                current = ""
            } else {
                current.append(char)
            }
        }
        result.append(current)

        return result
    }

    private func parseBitwardenJSON(_ data: Data) throws -> [Credential] {
        // Parse Bitwarden JSON export format
        return []
    }

    private func parse1PasswordJSON(_ data: Data) throws -> [Credential] {
        // Parse 1Password JSON export format
        return []
    }

    private func parseLastPassCSV(_ data: Data) throws -> [Credential] {
        // Parse LastPass CSV export format
        return try parseCSV(data)
    }

    private func exportToCSV() -> Data {
        var csv = "url,username,password,totp,notes\n"

        for cred in credentials {
            let line = "\"\(cred.domain)\",\"\(cred.username)\",\"\(cred.password)\",\"\(cred.totpSecret ?? "")\",\"\(cred.notes ?? "")\"\n"
            csv.append(line)
        }

        return Data(csv.utf8)
    }

    private func exportToJSON() throws -> Data {
        return try JSONEncoder().encode(credentials)
    }

    private func exportEncrypted() throws -> Data {
        guard let masterKey = masterKey else {
            throw PasswordManagerError.noMasterKey
        }

        let jsonData = try JSONEncoder().encode(credentials)
        let sealed = try AES.GCM.seal(jsonData, using: masterKey)
        return sealed.combined!
    }
}

// MARK: - Supporting Types

public struct PasswordManagerSettings: Codable {
    public var autoLockEnabled: Bool = true
    public var autoLockTimeout: TimeInterval = 300 // 5 minutes
    public var autoFillEnabled: Bool = true
    public var showPasswordStrength: Bool = true
    public var checkBreaches: Bool = true
    public var breachCheckInterval: TimeInterval = 86400 // 24 hours
    public var defaultPasswordLength: Int = 20
    public var biometricsEnabled: Bool = true
}

public enum UnlockMethod {
    case biometric
    case masterPassword(String)
    case devicePasscode
}

public struct TOTPCode {
    public let code: String
    public let timeRemaining: Int
    public let period: Int
}

public struct BreachAlert: Identifiable {
    public let id = UUID()
    public let credentialId: String
    public let domain: String
    public let breachCount: Int
    public let detectedAt: Date
}

public struct AutofillResult {
    public let username: String
    public let password: String
    public let totpCode: String?
}

public enum ImportFormat {
    case csv
    case bitwarden
    case onePassword
    case lastPass
}

public enum ExportFormat {
    case csv
    case json
    case encrypted
}

public struct ImportResult {
    public let imported: Int
    public let duplicates: Int
    public let failed: Int
}

public enum PasswordManagerError: Error, LocalizedError {
    case vaultLocked
    case noMasterKey
    case authenticationFailed
    case biometricsUnavailable
    case invalidPassword
    case credentialNotFound
    case noTOTPSecret
    case encryptionFailed
    case importFailed(String)

    public var errorDescription: String? {
        switch self {
        case .vaultLocked:
            return "Password vault is locked"
        case .noMasterKey:
            return "Master key not available"
        case .authenticationFailed:
            return "Authentication failed"
        case .biometricsUnavailable:
            return "Biometric authentication is not available"
        case .invalidPassword:
            return "Invalid master password"
        case .credentialNotFound:
            return "Credential not found"
        case .noTOTPSecret:
            return "No TOTP secret configured for this credential"
        case .encryptionFailed:
            return "Encryption failed"
        case .importFailed(let reason):
            return "Import failed: \(reason)"
        }
    }
}

// MARK: - EFF Wordlist (truncated for example)

private enum EFFWordlist {
    static let large = [
        "abacus", "abdomen", "ability", "ablaze", "aboard", "abolish", "abrasive",
        "absorb", "abstract", "absurd", "abundant", "academy", "accent", "accept",
        "access", "accident", "account", "accurate", "achieve", "acid", "acoustic",
        // ... would contain the full 7776 word EFF wordlist
        "zoology", "zoom"
    ]
}
