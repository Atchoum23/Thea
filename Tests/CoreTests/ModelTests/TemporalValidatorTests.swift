import Testing
import Foundation

// MARK: - TemporalValidator Test Double

/// Mirrors TemporalValidator from Shared/Core/Utilities/TemporalValidator.swift
private enum TestTemporalValidator {

    static func dayOfWeek(for date: Date, locale: Locale = Locale(identifier: "en_US")) -> String {
        let formatter = DateFormatter()
        formatter.locale = locale
        formatter.dateFormat = "EEEE"
        return formatter.string(from: date)
    }

    static func abbreviatedDayOfWeek(for date: Date, locale: Locale = Locale(identifier: "en_US")) -> String {
        let formatter = DateFormatter()
        formatter.locale = locale
        formatter.dateFormat = "EEE"
        return formatter.string(from: date)
    }

    static func validateDayDatePair(claimedDay: String, date: Date) -> String? {
        let actualDay = dayOfWeek(for: date, locale: Locale(identifier: "en_US")).lowercased()
        let claimed = claimedDay.lowercased().trimmingCharacters(in: .whitespaces)

        if actualDay == claimed || actualDay.hasPrefix(claimed) || claimed.hasPrefix(actualDay) {
            return nil
        }

        return dayOfWeek(for: date, locale: Locale(identifier: "en_US"))
    }

    static func scanAndCorrectDateDayMismatches(in text: String) -> String {
        var corrected = text
        let dayNames = ["Monday", "Tuesday", "Wednesday", "Thursday", "Friday", "Saturday", "Sunday"]
        let monthNames = [
            "January", "February", "March", "April", "May", "June",
            "July", "August", "September", "October", "November", "December"
        ]

        for dayName in dayNames {
            for (monthIndex, monthName) in monthNames.enumerated() {
                let patterns = [
                    "\(dayName) \(monthName) (\\d{1,2})",
                    "\(dayName), \(monthName) (\\d{1,2})"
                ]

                for pattern in patterns {
                    guard let regex = try? NSRegularExpression(pattern: pattern, options: []) else { continue }
                    let range = NSRange(corrected.startIndex..., in: corrected)
                    let matches = regex.matches(in: corrected, range: range)

                    for match in matches.reversed() {
                        guard let dayRange = Range(match.range(at: 1), in: corrected),
                              let dayNumber = Int(corrected[dayRange])
                        else { continue }

                        let calendar = Calendar(identifier: .gregorian)
                        var components = DateComponents()
                        components.month = monthIndex + 1
                        components.day = dayNumber
                        components.year = calendar.component(.year, from: Date())

                        guard let date = calendar.date(from: components) else { continue }

                        let actualDay = Self.dayOfWeek(for: date, locale: Locale(identifier: "en_US"))
                        if actualDay.lowercased() != dayName.lowercased() {
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

    static func isWeekend(_ date: Date) -> Bool {
        Calendar.current.isDateInWeekend(date)
    }

    static func daysBetween(_ from: Date, and to: Date) -> Int {
        Calendar.current.dateComponents([.day], from: Calendar.current.startOfDay(for: from),
                                        to: Calendar.current.startOfDay(for: to)).day ?? 0
    }

    static func timeOfDayGreeting(for date: Date = Date()) -> String {
        let hour = Calendar.current.component(.hour, from: date)
        switch hour {
        case 5..<12: return "Good morning"
        case 12..<17: return "Good afternoon"
        case 17..<22: return "Good evening"
        default: return "Good night"
        }
    }

    static func isValid(components: DateComponents) -> Bool {
        Calendar.current.date(from: components) != nil
    }
}

// MARK: - Test Helpers

private func makeDate(year: Int, month: Int, day: Int, hour: Int = 12, minute: Int = 0) -> Date {
    var cal = Calendar(identifier: .gregorian)
    cal.timeZone = TimeZone(identifier: "Europe/Zurich")!
    var components = DateComponents()
    components.year = year
    components.month = month
    components.day = day
    components.hour = hour
    components.minute = minute
    return cal.date(from: components)!
}

// MARK: - Tests

@Suite("TemporalValidator — Day of Week")
struct TemporalValidatorDayOfWeekTests {

    @Test("Known dates return correct day names")
    func knownDates() {
        // 2026-02-15 is a Sunday
        let feb15 = makeDate(year: 2026, month: 2, day: 15)
        #expect(TestTemporalValidator.dayOfWeek(for: feb15) == "Sunday")

        // 2026-01-01 is a Thursday
        let jan1 = makeDate(year: 2026, month: 1, day: 1)
        #expect(TestTemporalValidator.dayOfWeek(for: jan1) == "Thursday")

        // 2025-12-25 is a Thursday
        let christmas = makeDate(year: 2025, month: 12, day: 25)
        #expect(TestTemporalValidator.dayOfWeek(for: christmas) == "Thursday")
    }

    @Test("Abbreviated day names are correct")
    func abbreviatedDayNames() {
        let feb15 = makeDate(year: 2026, month: 2, day: 15)
        #expect(TestTemporalValidator.abbreviatedDayOfWeek(for: feb15) == "Sun")

        let feb16 = makeDate(year: 2026, month: 2, day: 16)
        #expect(TestTemporalValidator.abbreviatedDayOfWeek(for: feb16) == "Mon")
    }

    @Test("All 7 day names in a week")
    func fullWeekCycle() {
        // Starting Monday 2026-02-09
        let expectedDays = ["Monday", "Tuesday", "Wednesday", "Thursday", "Friday", "Saturday", "Sunday"]
        for (offset, expectedDay) in expectedDays.enumerated() {
            let date = makeDate(year: 2026, month: 2, day: 9 + offset)
            #expect(TestTemporalValidator.dayOfWeek(for: date) == expectedDay)
        }
    }

    @Test("Leap year date — Feb 29")
    func leapYear() {
        // 2024 is a leap year, Feb 29 is a Thursday
        let leapDay = makeDate(year: 2024, month: 2, day: 29)
        #expect(TestTemporalValidator.dayOfWeek(for: leapDay) == "Thursday")
    }

    @Test("Non-leap year — Feb 28 vs March 1")
    func nonLeapYear() {
        // 2026 is not a leap year
        let feb28 = makeDate(year: 2026, month: 2, day: 28)
        let mar1 = makeDate(year: 2026, month: 3, day: 1)
        // They should be consecutive days
        let feb28Day = TestTemporalValidator.dayOfWeek(for: feb28)
        let mar1Day = TestTemporalValidator.dayOfWeek(for: mar1)
        #expect(feb28Day == "Saturday")
        #expect(mar1Day == "Sunday")
    }
}

@Suite("TemporalValidator — Day-Date Pair Validation")
struct TemporalValidatorDayDatePairTests {

    @Test("Correct day returns nil (valid)")
    func correctDayReturnsNil() {
        let feb15 = makeDate(year: 2026, month: 2, day: 15)
        #expect(TestTemporalValidator.validateDayDatePair(claimedDay: "Sunday", date: feb15) == nil)
    }

    @Test("Wrong day returns correct day name")
    func wrongDayReturnsCorrection() {
        let feb15 = makeDate(year: 2026, month: 2, day: 15)
        let correction = TestTemporalValidator.validateDayDatePair(claimedDay: "Saturday", date: feb15)
        #expect(correction == "Sunday")
    }

    @Test("Case insensitive matching")
    func caseInsensitive() {
        let feb15 = makeDate(year: 2026, month: 2, day: 15)
        #expect(TestTemporalValidator.validateDayDatePair(claimedDay: "sunday", date: feb15) == nil)
        #expect(TestTemporalValidator.validateDayDatePair(claimedDay: "SUNDAY", date: feb15) == nil)
    }

    @Test("Prefix matching works")
    func prefixMatching() {
        let feb15 = makeDate(year: 2026, month: 2, day: 15)
        // "sun" should match "sunday"
        #expect(TestTemporalValidator.validateDayDatePair(claimedDay: "Sun", date: feb15) == nil)
    }

    @Test("Trimmed whitespace")
    func whitespace() {
        let feb15 = makeDate(year: 2026, month: 2, day: 15)
        #expect(TestTemporalValidator.validateDayDatePair(claimedDay: "  Sunday  ", date: feb15) == nil)
    }

    @Test("Every day of a week validated")
    func everyDayOfWeek() {
        let dayNames = ["Monday", "Tuesday", "Wednesday", "Thursday", "Friday", "Saturday", "Sunday"]
        for (offset, dayName) in dayNames.enumerated() {
            let date = makeDate(year: 2026, month: 2, day: 9 + offset)
            #expect(TestTemporalValidator.validateDayDatePair(claimedDay: dayName, date: date) == nil)
            // Wrong day should return the correct one
            let wrongDay = dayNames[(offset + 1) % 7]
            let correction = TestTemporalValidator.validateDayDatePair(claimedDay: wrongDay, date: date)
            #expect(correction == dayName)
        }
    }
}

@Suite("TemporalValidator — AI Response Scanning")
struct TemporalValidatorScanningTests {

    @Test("Correct date-day pair is unchanged")
    func correctPairUnchanged() {
        let text = "The meeting is on Sunday February 15."
        let result = TestTemporalValidator.scanAndCorrectDateDayMismatches(in: text)
        #expect(result == text)
    }

    @Test("Wrong day name is corrected")
    func wrongDayNameCorrected() {
        // Feb 15, 2026 is a Sunday
        let text = "The meeting is on Saturday February 15."
        let result = TestTemporalValidator.scanAndCorrectDateDayMismatches(in: text)
        #expect(result.contains("Sunday February 15"))
        #expect(!result.contains("Saturday February 15"))
    }

    @Test("Comma-separated format corrected")
    func commaFormat() {
        let text = "Join us Saturday, February 15 for the event."
        let result = TestTemporalValidator.scanAndCorrectDateDayMismatches(in: text)
        #expect(result.contains("Sunday, February 15"))
    }

    @Test("Multiple mismatches corrected")
    func multipleMismatches() {
        let text = "Monday February 15 and Tuesday February 16"
        let result = TestTemporalValidator.scanAndCorrectDateDayMismatches(in: text)
        // Feb 15 2026 = Sunday, Feb 16 2026 = Monday
        #expect(result.contains("Sunday February 15"))
        #expect(result.contains("Monday February 16"))
    }

    @Test("Text without date patterns is unchanged")
    func noDatePatterns() {
        let text = "Hello, how are you doing today? I hope everything is fine."
        let result = TestTemporalValidator.scanAndCorrectDateDayMismatches(in: text)
        #expect(result == text)
    }

    @Test("Already correct text is unchanged")
    func alreadyCorrect() {
        // Check known dates
        let text = "Thursday January 1 is New Year's Day."
        let result = TestTemporalValidator.scanAndCorrectDateDayMismatches(in: text)
        #expect(result == text)
    }
}

@Suite("TemporalValidator — Weekend Detection")
struct TemporalValidatorWeekendTests {

    @Test("Saturday is weekend")
    func saturdayIsWeekend() {
        let saturday = makeDate(year: 2026, month: 2, day: 14) // Saturday
        #expect(TestTemporalValidator.isWeekend(saturday) == true)
    }

    @Test("Sunday is weekend")
    func sundayIsWeekend() {
        let sunday = makeDate(year: 2026, month: 2, day: 15) // Sunday
        #expect(TestTemporalValidator.isWeekend(sunday) == true)
    }

    @Test("Monday is not weekend")
    func mondayIsNotWeekend() {
        let monday = makeDate(year: 2026, month: 2, day: 16) // Monday
        #expect(TestTemporalValidator.isWeekend(monday) == false)
    }

    @Test("Friday is not weekend")
    func fridayIsNotWeekend() {
        let friday = makeDate(year: 2026, month: 2, day: 13) // Friday
        #expect(TestTemporalValidator.isWeekend(friday) == false)
    }
}

@Suite("TemporalValidator — Days Between")
struct TemporalValidatorDaysBetweenTests {

    @Test("Same day returns 0")
    func sameDay() {
        let date = makeDate(year: 2026, month: 2, day: 15)
        #expect(TestTemporalValidator.daysBetween(date, and: date) == 0)
    }

    @Test("Adjacent days return 1")
    func adjacentDays() {
        let d1 = makeDate(year: 2026, month: 2, day: 15)
        let d2 = makeDate(year: 2026, month: 2, day: 16)
        #expect(TestTemporalValidator.daysBetween(d1, and: d2) == 1)
    }

    @Test("One week returns 7")
    func oneWeek() {
        let d1 = makeDate(year: 2026, month: 2, day: 1)
        let d2 = makeDate(year: 2026, month: 2, day: 8)
        #expect(TestTemporalValidator.daysBetween(d1, and: d2) == 7)
    }

    @Test("Negative direction returns negative")
    func negativeDirection() {
        let d1 = makeDate(year: 2026, month: 2, day: 20)
        let d2 = makeDate(year: 2026, month: 2, day: 15)
        #expect(TestTemporalValidator.daysBetween(d1, and: d2) == -5)
    }

    @Test("Across month boundary")
    func crossMonthBoundary() {
        let d1 = makeDate(year: 2026, month: 1, day: 30)
        let d2 = makeDate(year: 2026, month: 2, day: 2)
        #expect(TestTemporalValidator.daysBetween(d1, and: d2) == 3)
    }

    @Test("Across year boundary")
    func crossYearBoundary() {
        let d1 = makeDate(year: 2025, month: 12, day: 30)
        let d2 = makeDate(year: 2026, month: 1, day: 2)
        #expect(TestTemporalValidator.daysBetween(d1, and: d2) == 3)
    }

    @Test("Leap year February")
    func leapYearFebruary() {
        let d1 = makeDate(year: 2024, month: 2, day: 28)
        let d2 = makeDate(year: 2024, month: 3, day: 1)
        #expect(TestTemporalValidator.daysBetween(d1, and: d2) == 2) // Feb 29 in between
    }

    @Test("Non-leap year February")
    func nonLeapYearFebruary() {
        let d1 = makeDate(year: 2026, month: 2, day: 28)
        let d2 = makeDate(year: 2026, month: 3, day: 1)
        #expect(TestTemporalValidator.daysBetween(d1, and: d2) == 1)
    }
}

@Suite("TemporalValidator — Time of Day Greeting")
struct TemporalValidatorGreetingTests {

    @Test("Morning greeting 5-11")
    func morning() {
        for hour in 5..<12 {
            let date = makeDate(year: 2026, month: 2, day: 15, hour: hour)
            #expect(TestTemporalValidator.timeOfDayGreeting(for: date) == "Good morning")
        }
    }

    @Test("Afternoon greeting 12-16")
    func afternoon() {
        for hour in 12..<17 {
            let date = makeDate(year: 2026, month: 2, day: 15, hour: hour)
            #expect(TestTemporalValidator.timeOfDayGreeting(for: date) == "Good afternoon")
        }
    }

    @Test("Evening greeting 17-21")
    func evening() {
        for hour in 17..<22 {
            let date = makeDate(year: 2026, month: 2, day: 15, hour: hour)
            #expect(TestTemporalValidator.timeOfDayGreeting(for: date) == "Good evening")
        }
    }

    @Test("Night greeting 22-4")
    func night() {
        for hour in [22, 23, 0, 1, 2, 3, 4] {
            let date = makeDate(year: 2026, month: 2, day: 15, hour: hour)
            #expect(TestTemporalValidator.timeOfDayGreeting(for: date) == "Good night")
        }
    }

    @Test("Boundary: 5 AM is morning, 4 AM is night")
    func boundaryMorningNight() {
        let fiveAM = makeDate(year: 2026, month: 2, day: 15, hour: 5)
        let fourAM = makeDate(year: 2026, month: 2, day: 15, hour: 4)
        #expect(TestTemporalValidator.timeOfDayGreeting(for: fiveAM) == "Good morning")
        #expect(TestTemporalValidator.timeOfDayGreeting(for: fourAM) == "Good night")
    }

    @Test("Boundary: noon and 5 PM")
    func boundaryNoonEvening() {
        let noon = makeDate(year: 2026, month: 2, day: 15, hour: 12)
        let fivePM = makeDate(year: 2026, month: 2, day: 15, hour: 17)
        #expect(TestTemporalValidator.timeOfDayGreeting(for: noon) == "Good afternoon")
        #expect(TestTemporalValidator.timeOfDayGreeting(for: fivePM) == "Good evening")
    }
}

@Suite("TemporalValidator — DateComponents Validation")
struct TemporalValidatorDateComponentsTests {

    @Test("Valid date components")
    func validComponents() {
        var c = DateComponents()
        c.year = 2026
        c.month = 2
        c.day = 15
        #expect(TestTemporalValidator.isValid(components: c) == true)
    }

    @Test("Invalid date: Feb 30")
    func invalidFeb30() {
        var c = DateComponents()
        c.year = 2026
        c.month = 2
        c.day = 30
        // Calendar.date(from:) actually returns a date for invalid days (it rolls over)
        // So this just tests the function behavior
        let result = TestTemporalValidator.isValid(components: c)
        // Feb 30 rolls to March 2 in Calendar, so it is technically "valid" as a DateComponents
        #expect(result == true)
    }

    @Test("Valid leap year Feb 29")
    func validLeapYear() {
        var c = DateComponents()
        c.year = 2024
        c.month = 2
        c.day = 29
        #expect(TestTemporalValidator.isValid(components: c) == true)
    }

    @Test("Empty components")
    func emptyComponents() {
        let c = DateComponents()
        // Empty components are technically valid (defaults to reference date)
        #expect(TestTemporalValidator.isValid(components: c) == true)
    }

    @Test("Month 13 rolls over")
    func month13() {
        var c = DateComponents()
        c.year = 2026
        c.month = 13
        c.day = 1
        // Calendar rolls month 13 → January next year
        #expect(TestTemporalValidator.isValid(components: c) == true)
    }
}

@Suite("TemporalValidator — DST Transitions")
struct TemporalValidatorDSTTests {

    @Test("Days across DST spring forward")
    func dstSpringForward() {
        // In 2026, EU DST starts March 29
        let d1 = makeDate(year: 2026, month: 3, day: 28)
        let d2 = makeDate(year: 2026, month: 3, day: 30)
        #expect(TestTemporalValidator.daysBetween(d1, and: d2) == 2)
    }

    @Test("Days across DST fall back")
    func dstFallBack() {
        // In 2026, EU DST ends October 25
        let d1 = makeDate(year: 2026, month: 10, day: 24)
        let d2 = makeDate(year: 2026, month: 10, day: 26)
        #expect(TestTemporalValidator.daysBetween(d1, and: d2) == 2)
    }
}
