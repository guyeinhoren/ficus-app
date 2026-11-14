//
//  Formatting.swift
//  Hebrew wording and time formatting.
//

import Foundation

extension TimeInterval {
    /// `m:ss`, or `h:mm:ss` from one hour up.
    var clockString: String {
        let total = Int(self.rounded(.down))
        let (hours, minutes, seconds) = (total / 3600, total / 60 % 60, total % 60)
        return hours > 0
            ? String(format: "%d:%02d:%02d", hours, minutes, seconds)
            : String(format: "%02d:%02d", minutes, seconds)
    }

    /// A natural Hebrew description of a chosen duration: "25 דק׳", "שעה", "שעה ו-5 דק׳", "שעתיים".
    var hebrewLabel: String {
        let seconds = Int(self)
        if seconds < 60 { return "\(seconds) שנ׳" }
        let minutes = seconds / 60
        switch minutes {
        case ..<60: return "\(minutes) דק׳"
        case 60: return "שעה"
        case 120: return "שעתיים"
        default: return "שעה ו-\(minutes - 60) דק׳"
        }
    }
}

enum Hebrew {
    private static let weekdayLetters = ["א׳", "ב׳", "ג׳", "ד׳", "ה׳", "ו׳", "ש׳"]
    private static let masculineNumbers = ["שלושה", "ארבעה", "חמישה", "שישה", "שבעה", "שמונה", "תשעה", "עשרה"]

    /// Short weekday label ("א׳" for Sunday).
    static func weekday(of date: Date) -> String {
        weekdayLetters[Calendar.current.component(.weekday, from: date) - 1]
    }

    /// "נטעת שלושה עצים היום", "לא נטעת עצים ביום ד׳", …
    static func plantedSummary(count: Int, day: Int32) -> String {
        let trees = switch count {
        case 0: "לא נטעת עצים"
        case 1: "נטעת עץ אחד"
        case 2: "נטעת שני עצים"
        case 3...10: "נטעת \(masculineNumbers[count - 3]) עצים"
        default: "נטעת \(count) עצים"
        }
        return "\(trees) \(dayPhrase(day))"
    }

    private static func dayPhrase(_ day: Int32) -> String {
        let offset = Int(Day.today - day)
        let date = Day.date(of: day)
        switch offset {
        case 0: return "היום"
        case 1: return "אתמול"
        case 2..<7: return "ביום \(weekday(of: date))"
        default:
            let calendar = Calendar.current
            return "ב-\(calendar.component(.day, from: date)).\(calendar.component(.month, from: date))"
        }
    }
}
