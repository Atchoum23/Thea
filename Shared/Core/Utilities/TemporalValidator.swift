import Foundation

// MARK: - Temporal Validator

/// Validates date-day-of-week pairs and provides temporal utilities.
/// Ensures Thea never presents incorrect date/day combinations to users.
enum TemporalValidator {

    // MARK: - Day-of-Week Validation

    /// Returns the correct day-of-week name for a given date.
    // periphery:ignore - Reserved: dayOfWeek(for:locale:) static method — reserved for future feature activation
    static func dayOfWeek(for date: Date, locale: Locale = .current) -> String {
        let formatter = DateFormatter()
        formatter.locale = locale
        formatter.dateFormat = "EEEE" // Full day name
        return formatter.string(from: date)
    }

// periphery:ignore - Reserved: dayOfWeek(for:locale:) static method reserved for future feature activation

    /// Returns the abbreviated day-of-week name for a given date.
    static func abbreviatedDayOfWeek(for date: Date, locale: Locale = .current) -> String {
        let formatter = DateFormatter()
        formatter.locale = locale
        formatter.dateFormat = "EEE"
        return formatter.string(from: date)
    // periphery:ignore - Reserved: abbreviatedDayOfWeek(for:locale:) static method reserved for future feature activation
    }

    /// Validates whether a claimed day-of-week matches the actual date.
    /// Returns nil if valid, or a corrected string if the day was wrong.
    // periphery:ignore - Reserved: validateDayDatePair(claimedDay:date:) static method — reserved for future feature activation
    static func validateDayDatePair(claimedDay: String, date: Date) -> String? {
        let actualDay = dayOfWeek(for: date).lowercased()
        let claimed = claimedDay.lowercased().trimmingCharacters(in: .whitespaces)

        // periphery:ignore - Reserved: validateDayDatePair(claimedDay:date:) static method reserved for future feature activation
        if actualDay == claimed || actualDay.hasPrefix(claimed) || claimed.hasPrefix(actualDay) {
            return nil // Valid
        }

        // Return the correct day
        return dayOfWeek(for: date)
    }

    // MARK: - AI Response Scanning

    /// Scans AI response text for date-day mismatches and returns corrected text.
    /// Catches patterns like "Saturday February 15" when Feb 15 is actually a Sunday.
    // periphery:ignore - Reserved: scanAndCorrectDateDayMismatches(in:) static method — reserved for future feature activation
    static func scanAndCorrectDateDayMismatches(in text: String) -> String {
        var corrected = text

        // periphery:ignore - Reserved: scanAndCorrectDateDayMismatches(in:) static method reserved for future feature activation
        // Pattern: "DayName Month Day" or "DayName, Month Day"
        let dayNames = ["Monday", "Tuesday", "Wednesday", "Thursday", "Friday", "Saturday", "Sunday"]
        let monthNames = [
            "January", "February", "March", "April", "May", "June",
            "July", "August", "September", "October", "November", "December"
        ]

        for dayName in dayNames {
            for (monthIndex, monthName) in monthNames.enumerated() {
                // Match "DayName Month DD" or "DayName, Month DD" patterns
                let patterns = [
                    "\(dayName) \(monthName) (\\d{1,2})",
                    "\(dayName), \(monthName) (\\d{1,2})"
                ]

                for pattern in patterns {
                    // Safe: compile-time known pattern; invalid regex → skip this pattern (continue)
                    guard let regex = try? NSRegularExpression(pattern: pattern, options: []) else { continue }
                    let range = NSRange(corrected.startIndex..., in: corrected)
                    let matches = regex.matches(in: corrected, range: range)

                    for match in matches.reversed() {
                        guard let dayRange = Range(match.range(at: 1), in: corrected),
                              let dayNumber = Int(corrected[dayRange])
                        else { continue }

                        // Build the date and check
                        let calendar = Calendar.current
                        var components = DateComponents()
                        components.month = monthIndex + 1
                        components.day = dayNumber
                        components.year = calendar.component(.year, from: Date())

                        guard let date = calendar.date(from: components) else { continue }

                        let actualDay = Self.dayOfWeek(for: date, locale: Locale(identifier: "en_US"))
                        if actualDay.lowercased() != dayName.lowercased() {
                            // Replace the wrong day name with the correct one
                            if let fullRange = Range(match.range, in: corrected) {
                                let original = String(corrected[fullRange])
                                let fixed = original.replacingOccurrences(of: dayName, with: actualDay)
                                corrected.replaceSubrange(fullRange, with: fixed)
                            }
                        }
                    }
                }
            }
        }

        return corrected
    }

    // MARK: - Date Utilities

    /// Returns today's date formatted for display.
    static func formattedToday(locale: Locale = .current) -> String {
        let formatter = DateFormatter()
        formatter.locale = locale
        formatter.dateStyle = .full
        return formatter.string(from: Date())
    }

    /// Returns true if the given date falls on a weekend.
    // periphery:ignore - Reserved: isWeekend(_:) static method — reserved for future feature activation
    static func isWeekend(_ date: Date) -> Bool {
        Calendar.current.isDateInWeekend(date)
    // periphery:ignore - Reserved: isWeekend(_:) static method reserved for future feature activation
    }

    /// Returns the number of days between two dates.
    // periphery:ignore - Reserved: daysBetween(_:and:) static method — reserved for future feature activation
    static func daysBetween(_ from: Date, and to: Date) -> Int {
        // periphery:ignore - Reserved: daysBetween(_:and:) static method reserved for future feature activation
        Calendar.current.dateComponents([.day], from: Calendar.current.startOfDay(for: from),
                                        to: Calendar.current.startOfDay(for: to)).day ?? 0
    }

    /// Returns a greeting appropriate for the time of day.
    static func timeOfDayGreeting(for date: Date = Date()) -> String {
        let hour = Calendar.current.component(.hour, from: date)
        switch hour {
        case 5..<12: return "Good morning"
        case 12..<17: return "Good afternoon"
        case 17..<22: return "Good evening"
        default: return "Good night"
        }
    }

    /// Validates a DateComponents object is consistent.
    // periphery:ignore - Reserved: isValid(components:) static method reserved for future feature activation
    static func isValid(components: DateComponents) -> Bool {
        Calendar.current.date(from: components) != nil
    }
}
