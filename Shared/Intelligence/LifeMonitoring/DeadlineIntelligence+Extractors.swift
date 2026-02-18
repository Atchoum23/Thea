// DeadlineIntelligence+Extractors.swift
// THEA - Proactive Deadline & Timeline Tracking
// Created by Claude - February 2026
//
// Deadline extractor protocol and concrete implementations:
// DatePatternExtractor, KeywordExtractor, FinancialExtractor,
// LegalExtractor, MedicalExtractor, WorkExtractor

import Foundation

// MARK: - Deadline Extractor Protocol

/// Protocol for deadline extraction strategies.
///
/// Each extractor specializes in a particular extraction technique
/// (date patterns, keywords, financial terms, etc.) and is run by
/// ``DeadlineIntelligence`` against incoming content.
protocol DeadlineExtractor: Sendable {
    /// Human-readable name of this extractor (used in extraction context).
    var name: String { get }

    /// Extract deadlines from the given text content.
    /// - Parameters:
    ///   - content: The text to analyze.
    ///   - source: The origin of the content.
    ///   - context: Metadata about where and how the content was obtained.
    /// - Returns: Zero or more deadlines discovered in the content.
    func extract(from content: String, source: DeadlineSource, context: Deadline.ExtractionContext) async -> [Deadline]
}

// MARK: - Date Pattern Extractor

/// Extracts deadlines by matching explicit date patterns in text.
///
/// Recognizes patterns like "due by March 15, 2026", "deadline: April 1 2026",
/// "expires on June 30, 2026", etc. Supports multiple date formats.
struct DatePatternExtractor: DeadlineExtractor {
    let name = "DatePattern"

    func extract(from content: String, source: DeadlineSource, context: Deadline.ExtractionContext) async -> [Deadline] {
        var deadlines: [Deadline] = []

        // Patterns that indicate deadlines
        let deadlinePatterns = [
            (pattern: #"(?i)due\s+(by|on|before)\s+(\w+\s+\d{1,2}(?:st|nd|rd|th)?,?\s*\d{4})"#, prefix: "Due"),
            (pattern: #"(?i)deadline[:\s]+(\w+\s+\d{1,2}(?:st|nd|rd|th)?,?\s*\d{4})"#, prefix: "Deadline"),
            (pattern: #"(?i)must be (submitted|filed|completed) by\s+(\w+\s+\d{1,2}(?:st|nd|rd|th)?,?\s*\d{4})"#, prefix: "Submit by"),
            (pattern: #"(?i)payment due[:\s]+(\w+\s+\d{1,2}(?:st|nd|rd|th)?,?\s*\d{4})"#, prefix: "Payment due"),
            (pattern: #"(?i)expires?\s+(?:on\s+)?(\w+\s+\d{1,2}(?:st|nd|rd|th)?,?\s*\d{4})"#, prefix: "Expires"),
            (pattern: #"(?i)renew(?:al)?\s+(?:by|before)\s+(\w+\s+\d{1,2}(?:st|nd|rd|th)?,?\s*\d{4})"#, prefix: "Renew by")
        ]

        let dateFormatter = DateFormatter()
        dateFormatter.locale = Locale(identifier: "en_US")

        let dateFormats = [
            "MMMM d, yyyy",
            "MMMM d yyyy",
            "MMM d, yyyy",
            "MMM d yyyy",
            "MM/dd/yyyy",
            "MM-dd-yyyy",
            "yyyy-MM-dd"
        ]

        for (pattern, prefix) in deadlinePatterns {
            // Safe: compile-time known pattern; invalid regex → skip this pattern (no matches)
            if let regex = try? NSRegularExpression(pattern: pattern, options: []) {
                let nsContent = content as NSString
                let matches = regex.matches(in: content, options: [], range: NSRange(location: 0, length: nsContent.length))

                for match in matches {
                    let dateRangeIndex = match.numberOfRanges > 2 ? 2 : 1
                    guard dateRangeIndex < match.numberOfRanges else { continue }

                    let dateString = nsContent.substring(with: match.range(at: dateRangeIndex))
                        .trimmingCharacters(in: .whitespaces)
                        .replacingOccurrences(of: "st", with: "")
                        .replacingOccurrences(of: "nd", with: "")
                        .replacingOccurrences(of: "rd", with: "")
                        .replacingOccurrences(of: "th", with: "")

                    // Try parsing with different formats
                    var parsedDate: Date?
                    for format in dateFormats {
                        dateFormatter.dateFormat = format
                        if let date = dateFormatter.date(from: dateString) {
                            parsedDate = date
                            break
                        }
                    }

                    guard let dueDate = parsedDate else { continue }

                    // Extract surrounding context for title
                    let contextStart = max(0, match.range.location - 50)
                    let contextEnd = min(nsContent.length, match.range.location + match.range.length + 50)
                    let contextRange = NSRange(location: contextStart, length: contextEnd - contextStart)
                    let surrounding = nsContent.substring(with: contextRange)

                    // Determine category from context
                    let category = categorize(content: content, surrounding: surrounding)

                    let deadline = Deadline(
                        title: "\(prefix): \(dateString)",
                        description: surrounding.trimmingCharacters(in: .whitespacesAndNewlines),
                        dueDate: dueDate,
                        source: source,
                        category: category,
                        extractedFrom: context,
                        confidence: 0.7
                    )

                    deadlines.append(deadline)
                }
            }
        }

        return deadlines
    }

    /// Categorize content based on keyword analysis.
    /// - Parameters:
    ///   - content: The full content being analyzed.
    ///   - surrounding: Text surrounding the matched date pattern.
    /// - Returns: The most likely category for the deadline.
    private func categorize(content: String, surrounding: String) -> DeadlineCategory {
        let lowercased = (content + " " + surrounding).lowercased()

        if lowercased.contains("tax") || lowercased.contains("irs") || lowercased.contains("1040") {
            return .financial
        } else if lowercased.contains("payment") || lowercased.contains("bill") || lowercased.contains("invoice") {
            return .financial
        } else if lowercased.contains("legal") || lowercased.contains("court") || lowercased.contains("lawsuit") {
            return .legal
        } else if lowercased.contains("doctor") || lowercased.contains("appointment") || lowercased.contains("medical") {
            return .health
        } else if lowercased.contains("project") || lowercased.contains("work") || lowercased.contains("meeting") {
            return .work
        } else if lowercased.contains("license") || lowercased.contains("registration") || lowercased.contains("renew") {
            return .administrative
        }

        return .personal
    }
}

// MARK: - Keyword Extractor

/// Extracts deadlines from relative date expressions and action keywords.
///
/// Recognizes patterns like "need to submit by tomorrow",
/// "remind me to call next week", "expires in 30 days", etc.
struct KeywordExtractor: DeadlineExtractor {
    let name = "Keyword"

    func extract(from content: String, source: DeadlineSource, context: Deadline.ExtractionContext) async -> [Deadline] {
        var deadlines: [Deadline] = []

        // Keyword patterns with relative dates
        let relativePatterns = [
            (#"(?i)(need|must|have to|should)\s+(\w+(?:\s+\w+)?)\s+by\s+(tomorrow|today|next\s+\w+|this\s+\w+)"#, ""),
            (#"(?i)remind me to\s+(.+?)\s+(tomorrow|next week|next month|on \w+day)"#, "Reminder"),
            (#"(?i)(expires?|expiring)\s+(in\s+\d+\s+(?:days?|weeks?|months?))"#, "Expiring")
        ]

        for (pattern, prefix) in relativePatterns {
            // Safe: compile-time known pattern; invalid regex → skip this pattern (no matches)
            if let regex = try? NSRegularExpression(pattern: pattern, options: []) {
                let nsContent = content as NSString
                let matches = regex.matches(in: content, options: [], range: NSRange(location: 0, length: nsContent.length))

                for match in matches {
                    // Extract action and time reference
                    guard match.numberOfRanges >= 3 else { continue }

                    let timeRef = nsContent.substring(with: match.range(at: match.numberOfRanges - 1))
                    guard let dueDate = parseRelativeDate(timeRef) else { continue }

                    let fullMatch = nsContent.substring(with: match.range)
                    let title = prefix.isEmpty ? fullMatch : "\(prefix): \(fullMatch)"

                    let deadline = Deadline(
                        title: title,
                        dueDate: dueDate,
                        source: source,
                        category: .personal,
                        extractedFrom: context,
                        confidence: 0.6
                    )

                    deadlines.append(deadline)
                }
            }
        }

        return deadlines
    }

    /// Parse a relative date expression into an absolute date.
    /// - Parameter text: Relative date text (e.g. "tomorrow", "next week", "in 3 days").
    /// - Returns: The resolved date, or nil if unparseable.
    private func parseRelativeDate(_ text: String) -> Date? {
        let lowercased = text.lowercased()
        let calendar = Calendar.current
        let now = Date()

        if lowercased == "today" {
            return calendar.date(bySettingHour: 17, minute: 0, second: 0, of: now)
        } else if lowercased == "tomorrow" {
            return calendar.date(byAdding: .day, value: 1, to: now)
        } else if lowercased.contains("next week") {
            return calendar.date(byAdding: .weekOfYear, value: 1, to: now)
        } else if lowercased.contains("next month") {
            return calendar.date(byAdding: .month, value: 1, to: now)
        } else if lowercased.contains("this week") {
            // End of this week (Friday)
            let weekday = calendar.component(.weekday, from: now)
            let daysUntilFriday = (6 - weekday + 7) % 7
            return calendar.date(byAdding: .day, value: daysUntilFriday, to: now)
        }

        // Parse "in X days/weeks/months"
        // Safe: compile-time known pattern; invalid regex → return nil (no match)
        if let regex = try? NSRegularExpression(pattern: #"in\s+(\d+)\s+(days?|weeks?|months?)"#, options: .caseInsensitive) {
            let nsText = text as NSString
            if let match = regex.firstMatch(in: text, options: [], range: NSRange(location: 0, length: nsText.length)) {
                let number = Int(nsText.substring(with: match.range(at: 1))) ?? 0
                let unit = nsText.substring(with: match.range(at: 2)).lowercased()

                if unit.starts(with: "day") {
                    return calendar.date(byAdding: .day, value: number, to: now)
                } else if unit.starts(with: "week") {
                    return calendar.date(byAdding: .weekOfYear, value: number, to: now)
                } else if unit.starts(with: "month") {
                    return calendar.date(byAdding: .month, value: number, to: now)
                }
            }
        }

        return nil
    }
}

// MARK: - Financial Extractor

/// Extracts financial deadlines such as bills, tax returns, and payments.
///
/// Recognizes tax filing deadlines, payment due dates, balance due notices,
/// and minimum payment reminders with associated consequences.
struct FinancialExtractor: DeadlineExtractor {
    let name = "Financial"

    func extract(from content: String, source: DeadlineSource, context: Deadline.ExtractionContext) async -> [Deadline] {
        var deadlines: [Deadline] = []

        // Tax deadline patterns
        let taxPatterns = [
            (#"(?i)tax return.+due.+(\w+\s+\d{1,2},?\s*\d{4})"#, "Tax Return Due", [
                "Late filing penalty",
                "Interest on unpaid taxes",
                "Possible audit flag"
            ]),
            (#"(?i)quarterly estimated tax.+(\w+\s+\d{1,2},?\s*\d{4})"#, "Estimated Tax Payment", [
                "Underpayment penalty"
            ]),
            (#"(?i)(?:1099|W-2|W2).+(?:file|submit|send).+(\w+\s+\d{1,2},?\s*\d{4})"#, "Tax Form Submission", [])
        ]

        // Bill patterns
        let billPatterns = [
            (#"(?i)payment of \$[\d,]+(?:\.\d{2})? (?:is )?due.+(\w+\s+\d{1,2},?\s*\d{4})"#, "Bill Payment", [
                "Late payment fee",
                "Service interruption"
            ]),
            (#"(?i)balance of \$[\d,]+(?:\.\d{2})?.+due by.+(\w+\s+\d{1,2},?\s*\d{4})"#, "Balance Due", []),
            (#"(?i)minimum payment.+\$[\d,]+(?:\.\d{2})?.+due.+(\w+\s+\d{1,2},?\s*\d{4})"#, "Minimum Payment Due", [
                "Late fee",
                "Interest charges",
                "Credit score impact"
            ])
        ]

        // Process patterns
        deadlines.append(contentsOf: processPatterns(taxPatterns, in: content, source: source, context: context, category: .financial))
        deadlines.append(contentsOf: processPatterns(billPatterns, in: content, source: source, context: context, category: .financial))

        return deadlines
    }

    /// Process an array of regex patterns against content to extract deadlines.
    /// - Parameters:
    ///   - patterns: Tuples of (regex pattern, title, consequences).
    ///   - content: The text to search.
    ///   - source: Origin of the content.
    ///   - context: Extraction metadata.
    ///   - category: Category to assign to discovered deadlines.
    /// - Returns: Deadlines matched by the patterns.
    private func processPatterns(
        _ patterns: [(String, String, [String])],
        in content: String,
        source: DeadlineSource,
        context: Deadline.ExtractionContext,
        category: DeadlineCategory
    ) -> [Deadline] {
        var deadlines: [Deadline] = []

        let dateFormatter = DateFormatter()
        dateFormatter.locale = Locale(identifier: "en_US")
        let dateFormats = ["MMMM d, yyyy", "MMMM d yyyy", "MMM d, yyyy"]

        for (pattern, title, consequences) in patterns {
            // Safe: compile-time known pattern; invalid regex → skip this pattern (no matches)
            if let regex = try? NSRegularExpression(pattern: pattern, options: []) {
                let nsContent = content as NSString
                let matches = regex.matches(in: content, options: [], range: NSRange(location: 0, length: nsContent.length))

                for match in matches {
                    guard match.numberOfRanges >= 2 else { continue }

                    let dateString = nsContent.substring(with: match.range(at: 1))
                        .trimmingCharacters(in: .whitespaces)

                    var parsedDate: Date?
                    for format in dateFormats {
                        dateFormatter.dateFormat = format
                        if let date = dateFormatter.date(from: dateString) {
                            parsedDate = date
                            break
                        }
                    }

                    guard let dueDate = parsedDate else { continue }

                    let deadline = Deadline(
                        title: title,
                        description: nsContent.substring(with: match.range),
                        dueDate: dueDate,
                        source: source,
                        category: category,
                        priority: category.defaultPriority,
                        consequences: consequences.isEmpty ? nil : consequences,
                        extractedFrom: context,
                        confidence: 0.85
                    )

                    deadlines.append(deadline)
                }
            }
        }

        return deadlines
    }
}

// MARK: - Legal Extractor

/// Extracts legal deadlines (court dates, filing deadlines, statute of limitations).
struct LegalExtractor: DeadlineExtractor {
    let name = "Legal"

    func extract(from content: String, source: DeadlineSource, context: Deadline.ExtractionContext) async -> [Deadline] {
        // Legal deadline extraction (court dates, filing deadlines, statute of limitations)
        // Implementation would check for legal terminology and deadlines
        []
    }
}

// MARK: - Medical Extractor

/// Extracts medical and health deadlines (appointments, prescription refills, checkups).
struct MedicalExtractor: DeadlineExtractor {
    let name = "Medical"

    func extract(from content: String, source: DeadlineSource, context: Deadline.ExtractionContext) async -> [Deadline] {
        // Medical deadline extraction (appointments, prescription refills, checkups)
        // Implementation would check for medical terminology
        []
    }
}

// MARK: - Work Extractor

/// Extracts work-related deadlines (project deadlines, meetings, reviews).
struct WorkExtractor: DeadlineExtractor {
    let name = "Work"

    func extract(from content: String, source: DeadlineSource, context: Deadline.ExtractionContext) async -> [Deadline] {
        // Work deadline extraction (project deadlines, meetings, reviews)
        // Implementation would check for work terminology
        []
    }
}
