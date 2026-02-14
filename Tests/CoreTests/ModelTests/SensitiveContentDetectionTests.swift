// SensitiveContentDetectionTests.swift
// Tests for clipboard sensitive content detection regex patterns
// Mirrors ClipboardHistoryManager.isSensitiveContent() logic

import Testing
import Foundation

// MARK: - Test Double

/// Mirrors the 6 sensitive content regex patterns from ClipboardHistoryManager
private struct SensitiveContentDetector: Sendable {
    let patterns: [NSRegularExpression]

    init() {
        let patternStrings = [
            // Strong password pattern: 8+ chars with letters + digits
            "(?=.*[A-Za-z])(?=.*\\d)[A-Za-z\\d@$!%*#?&]{8,}",
            // Credit card: 13-16 digits with optional spaces/dashes
            "\\b(?:\\d[ -]*?){13,16}\\b",
            // Social Security: XXX-XX-XXXX
            "\\b\\d{3}-\\d{2}-\\d{4}\\b",
            // API key/secret patterns
            "(?i)(api[_-]?key|apikey|secret[_-]?key|access[_-]?token)[\"']?\\s*[:=]\\s*[\"']?[a-zA-Z0-9_-]{20,}",
            // AWS Access Key
            "(?i)AKIA[0-9A-Z]{16}",
            // PEM Private Key
            "-----BEGIN (RSA |EC |DSA |OPENSSH )?PRIVATE KEY-----"
        ]

        var compiled: [NSRegularExpression] = []
        for pattern in patternStrings {
            if let regex = try? NSRegularExpression(pattern: pattern, options: []) {
                compiled.append(regex)
            }
        }
        patterns = compiled
    }

    func isSensitive(_ text: String) -> Bool {
        let range = NSRange(text.startIndex..., in: text)
        for pattern in patterns {
            if pattern.firstMatch(in: text, options: [], range: range) != nil {
                return true
            }
        }
        return false
    }
}

private let detector = SensitiveContentDetector()

// MARK: - Tests

@Suite("Pattern Compilation")
struct PatternCompilationTests {
    @Test("All 6 patterns compile successfully")
    func allPatternsCompile() {
        #expect(detector.patterns.count == 6)
    }
}

@Suite("Password Detection")
struct PasswordDetectionTests {
    @Test("Strong password detected: letters + digits, 8+ chars")
    func strongPassword() {
        #expect(detector.isSensitive("MyPass123"))
    }

    @Test("Password with special chars detected")
    func passwordWithSpecial() {
        #expect(detector.isSensitive("P@ssw0rd!"))
    }

    @Test("Short password not detected: under 8 chars")
    func shortPassword() {
        #expect(!detector.isSensitive("abc12"))
    }

    @Test("Letters only not detected as password")
    func lettersOnly() {
        #expect(!detector.isSensitive("HelloWorld"))
    }

    @Test("Digits only not detected as password")
    func digitsOnly() {
        #expect(!detector.isSensitive("12345678"))
    }

    @Test("Normal sentence not detected")
    func normalSentence() {
        #expect(!detector.isSensitive("Hello, how are you today?"))
    }
}

@Suite("Credit Card Detection")
struct CreditCardDetectionTests {
    @Test("16-digit card number with dashes")
    func dashedCardNumber() {
        #expect(detector.isSensitive("4532-1111-2222-3333"))
    }

    @Test("16-digit card number with spaces")
    func spacedCardNumber() {
        #expect(detector.isSensitive("4532 1111 2222 3333"))
    }

    @Test("16-digit card number contiguous")
    func contiguousCardNumber() {
        #expect(detector.isSensitive("4532111122223333"))
    }

    @Test("13-digit card number (Visa old)")
    func shortCardNumber() {
        #expect(detector.isSensitive("4111111111111"))
    }

    @Test("Too few digits not detected")
    func tooFewDigits() {
        #expect(!detector.isSensitive("1234-5678"))
    }
}

@Suite("SSN Detection")
struct SSNDetectionTests {
    @Test("Standard SSN format")
    func standardSSN() {
        #expect(detector.isSensitive("123-45-6789"))
    }

    @Test("SSN in context")
    func ssnInContext() {
        #expect(detector.isSensitive("My SSN is 123-45-6789 for reference"))
    }

    @Test("Wrong format not detected")
    func wrongFormat() {
        #expect(!detector.isSensitive("123-456789"))
    }

    @Test("No dashes not detected")
    func noDashes() {
        #expect(!detector.isSensitive("123456789"))
    }
}

@Suite("API Key Detection")
struct APIKeyDetectionTests {
    @Test("API key assignment")
    func apiKeyAssignment() {
        #expect(detector.isSensitive("api_key = 'abc123def456xyz789abc123def456'"))
    }

    @Test("API key with equals")
    func apiKeyEquals() {
        #expect(detector.isSensitive("apikey=abcdefghijklmnopqrstuvwxyz"))
    }

    @Test("Secret key pattern")
    func secretKey() {
        #expect(detector.isSensitive("secret_key: abcdefghijklmnopqrstuvwxyz"))
    }

    @Test("Access token pattern")
    func accessToken() {
        #expect(detector.isSensitive("access_token = abcdefghijklmnopqrstuvwxyz"))
    }

    @Test("Case insensitive")
    func caseInsensitive() {
        #expect(detector.isSensitive("API_KEY = abcdefghijklmnopqrstuvwxyz"))
        #expect(detector.isSensitive("Api_Key = abcdefghijklmnopqrstuvwxyz"))
    }

    @Test("Short value not detected")
    func shortValue() {
        #expect(!detector.isSensitive("apiKey='short'"))
    }

    @Test("Normal text with 'api' not detected")
    func normalApiText() {
        #expect(!detector.isSensitive("The API is working great today"))
    }
}

@Suite("AWS Key Detection")
struct AWSKeyDetectionTests {
    @Test("AWS access key format")
    func awsKey() {
        #expect(detector.isSensitive("AKIAIOSFODNN7EXAMPLE"))
    }

    @Test("AWS key in context")
    func awsKeyInContext() {
        #expect(detector.isSensitive("aws_access_key_id = AKIAIOSFODNN7EXAMPLE"))
    }

    @Test("Case insensitive AWS")
    func caseInsensitiveAWS() {
        #expect(detector.isSensitive("akiaiosfodnn7example"))
    }

    @Test("Short AKIA string — also matches password pattern (letters+digits 8+ chars)")
    func shortAKIAMatchesPasswordPattern() {
        // AKIA1234 is 8 chars with letters+digits → triggers the strong password regex
        #expect(detector.isSensitive("AKIA1234"))
    }

    @Test("Non-AKIA alphanumeric — matches password pattern too")
    func nonAKIAMatchesPasswordPattern() {
        // XXXAIOSFODNN7EXAMPLE has letters+digits 20 chars → triggers password regex
        #expect(detector.isSensitive("XXXAIOSFODNN7EXAMPLE"))
    }

    @Test("AKIA with all uppercase matches AWS pattern (A-Z is valid)")
    func akiaUppercaseMatchesAWS() {
        // (?i)AKIA[0-9A-Z]{16} — uppercase Z matches [A-Z], so AKIA + 16 Z's = valid AWS key
        #expect(detector.isSensitive("AKIAZZZZZZZZZZZZZZZZ"))
    }

    @Test("Non-AKIA prefix with all lowercase not detected")
    func nonAKIALowercaseNotDetected() {
        // All lowercase, no digits, no AKIA prefix → not detected
        #expect(!detector.isSensitive("helloworldexample"))
    }
}

@Suite("PEM Key Detection")
struct PEMKeyDetectionTests {
    @Test("Standard private key header")
    func standardHeader() {
        #expect(detector.isSensitive("-----BEGIN PRIVATE KEY-----"))
    }

    @Test("RSA private key header")
    func rsaHeader() {
        #expect(detector.isSensitive("-----BEGIN RSA PRIVATE KEY-----"))
    }

    @Test("EC private key header")
    func ecHeader() {
        #expect(detector.isSensitive("-----BEGIN EC PRIVATE KEY-----"))
    }

    @Test("DSA private key header")
    func dsaHeader() {
        #expect(detector.isSensitive("-----BEGIN DSA PRIVATE KEY-----"))
    }

    @Test("OpenSSH private key header")
    func opensshHeader() {
        #expect(detector.isSensitive("-----BEGIN OPENSSH PRIVATE KEY-----"))
    }

    @Test("Public key header not detected")
    func publicKeyNotDetected() {
        #expect(!detector.isSensitive("-----BEGIN PUBLIC KEY-----"))
    }

    @Test("Certificate not detected")
    func certificateNotDetected() {
        #expect(!detector.isSensitive("-----BEGIN CERTIFICATE-----"))
    }
}

@Suite("Non-Sensitive Content")
struct NonSensitiveContentTests {
    @Test("Regular English text")
    func regularText() {
        #expect(!detector.isSensitive("This is a regular paragraph of text."))
    }

    @Test("Short numeric text")
    func shortNumeric() {
        #expect(!detector.isSensitive("42"))
    }

    @Test("URL not detected")
    func urlNotDetected() {
        #expect(!detector.isSensitive("https://example.com/path"))
    }

    @Test("Email not detected by these patterns")
    func emailNotDetected() {
        #expect(!detector.isSensitive("user@example.com"))
    }

    @Test("Phone number not detected by these patterns")
    func phoneNotDetected() {
        #expect(!detector.isSensitive("+1 (555) 123-4567"))
    }

    @Test("Empty string not detected")
    func emptyString() {
        #expect(!detector.isSensitive(""))
    }

    @Test("Code snippet without secrets")
    func codeSnippet() {
        #expect(!detector.isSensitive("func hello() { print(\"world\") }"))
    }

    @Test("JSON without secrets")
    func jsonWithoutSecrets() {
        #expect(!detector.isSensitive("{\"name\": \"John\", \"age\": 30}"))
    }
}

@Suite("Edge Cases")
struct SensitiveEdgeCaseTests {
    @Test("Multiple patterns in one text")
    func multiplePatterns() {
        let text = "SSN: 123-45-6789, Card: 4532-1111-2222-3333"
        #expect(detector.isSensitive(text))
    }

    @Test("Pattern at end of text")
    func patternAtEnd() {
        #expect(detector.isSensitive("My SSN is 123-45-6789"))
    }

    @Test("Pattern at start of text")
    func patternAtStart() {
        #expect(detector.isSensitive("123-45-6789 is my SSN"))
    }

    @Test("Unicode text without sensitive data")
    func unicodeClean() {
        #expect(!detector.isSensitive("日本語のテキスト"))
    }

    @Test("Emoji text without sensitive data")
    func emojiClean() {
        #expect(!detector.isSensitive("Hello 👋 World 🌍"))
    }

    @Test("Very long non-sensitive text")
    func longText() {
        let text = String(repeating: "This is a normal sentence. ", count: 100)
        #expect(!detector.isSensitive(text))
    }
}
