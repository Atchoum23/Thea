//
//  TOTPAuthenticator.swift
//  Thea
//
//  TOTP (RFC 6238) two-factor authentication for remote desktop connections
//

import CryptoKit
import Foundation

// MARK: - TOTP Authenticator

/// Two-factor authentication using Time-based One-Time Passwords (RFC 6238)
@MainActor
public class TOTPAuthenticator: ObservableObject {
    // MARK: - Published State

    @Published public private(set) var isEnabled = false
    @Published public private(set) var hasSecret = false

    // MARK: - Constants

    private static let keychainService = "app.thea.remote.totp"
    private static let secretKey = "totp_secret"
    private static let recoveryCodesKey = "totp_recovery"
    private static let digits = 6
    private static let period: TimeInterval = 30
    private static let secretLength = 20 // 160 bits

    // MARK: - Initialization

    public init() {
        hasSecret = loadSecret() != nil
        isEnabled = hasSecret && UserDefaults.standard.bool(forKey: "thea.remote.totp.enabled")
    }

    // MARK: - Setup

    /// Generate a new TOTP secret and recovery codes
    public func setup() -> TOTPSetupInfo {
        let secret = generateSecret()
        let recoveryCodes = generateRecoveryCodes(count: 8)

        saveSecret(secret)
        saveRecoveryCodes(recoveryCodes)

        hasSecret = true

        let base32Secret = base32Encode(secret)
        let issuer = "Thea Remote Desktop"
        let account = Host.current().localizedName ?? "Mac"
        let otpauthURL = "otpauth://totp/\(urlEncode(issuer)):\(urlEncode(account))?secret=\(base32Secret)&issuer=\(urlEncode(issuer))&digits=\(Self.digits)&period=\(Int(Self.period))"

        return TOTPSetupInfo(
            secret: base32Secret,
            otpauthURL: otpauthURL,
            recoveryCodes: recoveryCodes,
            issuer: issuer,
            account: account
        )
    }

    /// Enable TOTP after successful verification
    public func enable(verificationCode: String) -> Bool {
        guard verify(code: verificationCode) else { return false }
        isEnabled = true
        UserDefaults.standard.set(true, forKey: "thea.remote.totp.enabled")
        return true
    }

    /// Disable TOTP
    public func disable() {
        isEnabled = false
        UserDefaults.standard.set(false, forKey: "thea.remote.totp.enabled")
    }

    /// Remove TOTP configuration entirely
    public func reset() {
        disable()
        deleteKeychainItem(key: Self.secretKey)
        deleteKeychainItem(key: Self.recoveryCodesKey)
        hasSecret = false
    }

    // MARK: - Verification

    /// Verify a TOTP code (allows 1 period window in each direction)
    public func verify(code: String) -> Bool {
        guard let secret = loadSecret() else { return false }

        let trimmed = code.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.count == Self.digits else { return false }

        let now = Date()

        // Check current period and adjacent periods (±1 window for clock skew)
        for offset in -1 ... 1 {
            let time = now.addingTimeInterval(Double(offset) * Self.period)
            let expected = generateCode(secret: secret, date: time)
            if constantTimeCompare(trimmed, expected) {
                return true
            }
        }

        return false
    }

    /// Verify a recovery code (single use)
    public func verifyRecoveryCode(_ code: String) -> Bool {
        guard var codes = loadRecoveryCodes() else { return false }

        let trimmed = code.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
        guard let index = codes.firstIndex(of: trimmed) else { return false }

        codes.remove(at: index)
        saveRecoveryCodes(codes)
        return true
    }

    /// Get remaining recovery codes count
    public var remainingRecoveryCodes: Int {
        loadRecoveryCodes()?.count ?? 0
    }

    // MARK: - Code Generation

    /// Generate TOTP code for the current time (for testing/display)
    public func currentCode() -> String? {
        guard let secret = loadSecret() else { return nil }
        return generateCode(secret: secret, date: Date())
    }

    /// Time remaining until current code expires
    public var secondsRemaining: Int {
        let epoch = Date().timeIntervalSince1970
        let elapsed = Int(epoch) % Int(Self.period)
        return Int(Self.period) - elapsed
    }

    // MARK: - TOTP Algorithm (RFC 6238)

    private func generateCode(secret: Data, date: Date) -> String {
        let counter = UInt64(date.timeIntervalSince1970 / Self.period)

        // Counter as big-endian 8-byte value
        var counterBE = counter.bigEndian
        let counterData = Data(bytes: &counterBE, count: 8)

        // HMAC-SHA1
        let key = SymmetricKey(data: secret)
        let hmac = HMAC<Insecure.SHA1>.authenticationCode(for: counterData, using: key)
        let hmacBytes = Array(hmac)

        // Dynamic truncation
        let offset = Int(hmacBytes[hmacBytes.count - 1] & 0x0F)
        let truncated = (Int(hmacBytes[offset]) & 0x7F) << 24
            | Int(hmacBytes[offset + 1]) << 16
            | Int(hmacBytes[offset + 2]) << 8
            | Int(hmacBytes[offset + 3])

        let otp = truncated % Int(pow(10, Double(Self.digits)))
        return String(format: "%0\(Self.digits)d", otp)
    }

    // MARK: - Secret Management

    private func generateSecret() -> Data {
        var bytes = [UInt8](repeating: 0, count: Self.secretLength)
        _ = SecRandomCopyBytes(kSecRandomDefault, Self.secretLength, &bytes)
        return Data(bytes)
    }

    private func generateRecoveryCodes(count: Int) -> [String] {
        (0 ..< count).map { _ in
            let chars = "ABCDEFGHJKLMNPQRSTUVWXYZ23456789" // Removed ambiguous chars
            var code = ""
            for i in 0 ..< 8 {
                if i == 4 { code += "-" }
                let index = Int.random(in: 0 ..< chars.count)
                code += String(chars[chars.index(chars.startIndex, offsetBy: index)])
            }
            return code
        }
    }

    // MARK: - Keychain

    private func saveSecret(_ data: Data) {
        saveKeychainItem(key: Self.secretKey, data: data)
    }

    private func loadSecret() -> Data? {
        loadKeychainItem(key: Self.secretKey)
    }

    private func saveRecoveryCodes(_ codes: [String]) {
        guard let data = try? JSONEncoder().encode(codes) else { return }
        saveKeychainItem(key: Self.recoveryCodesKey, data: data)
    }

    private func loadRecoveryCodes() -> [String]? {
        guard let data = loadKeychainItem(key: Self.recoveryCodesKey) else { return nil }
        return try? JSONDecoder().decode([String].self, from: data)
    }

    private func saveKeychainItem(key: String, data: Data) {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: Self.keychainService,
            kSecAttrAccount as String: key
        ]

        SecItemDelete(query as CFDictionary)

        var newItem = query
        newItem[kSecValueData as String] = data
        newItem[kSecAttrAccessible as String] = kSecAttrAccessibleWhenUnlockedThisDeviceOnly

        SecItemAdd(newItem as CFDictionary, nil)
    }

    private func loadKeychainItem(key: String) -> Data? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: Self.keychainService,
            kSecAttrAccount as String: key,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]

        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        guard status == errSecSuccess else { return nil }
        return result as? Data
    }

    private func deleteKeychainItem(key: String) {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: Self.keychainService,
            kSecAttrAccount as String: key
        ]
        SecItemDelete(query as CFDictionary)
    }

    // MARK: - Encoding Helpers

    private func base32Encode(_ data: Data) -> String {
        let alphabet = "ABCDEFGHIJKLMNOPQRSTUVWXYZ234567"
        let bytes = Array(data)
        var result = ""
        var buffer = 0
        var bitsLeft = 0

        for byte in bytes {
            buffer = (buffer << 8) | Int(byte)
            bitsLeft += 8

            while bitsLeft >= 5 {
                bitsLeft -= 5
                let index = (buffer >> bitsLeft) & 0x1F
                result += String(alphabet[alphabet.index(alphabet.startIndex, offsetBy: index)])
            }
        }

        if bitsLeft > 0 {
            let index = (buffer << (5 - bitsLeft)) & 0x1F
            result += String(alphabet[alphabet.index(alphabet.startIndex, offsetBy: index)])
        }

        return result
    }

    private func urlEncode(_ string: String) -> String {
        string.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? string
    }

    private func constantTimeCompare(_ a: String, _ b: String) -> Bool {
        guard a.count == b.count else { return false }
        let aBytes = Array(a.utf8)
        let bBytes = Array(b.utf8)
        var result: UInt8 = 0
        for i in 0 ..< aBytes.count {
            result |= aBytes[i] ^ bBytes[i]
        }
        return result == 0
    }
}

// MARK: - TOTP Setup Info

public struct TOTPSetupInfo: Sendable {
    public let secret: String
    public let otpauthURL: String
    public let recoveryCodes: [String]
    public let issuer: String
    public let account: String
}
