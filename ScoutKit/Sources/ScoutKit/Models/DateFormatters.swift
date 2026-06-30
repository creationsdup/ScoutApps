import Foundation

enum SGDFDate {
    static let iso: DateFormatter = {
        let f = DateFormatter()
        f.locale = Locale(identifier: "en_US_POSIX")
        f.dateFormat = "yyyy-MM-dd"
        return f
    }()

    static func day(from string: String) -> Date? {
        iso.date(from: string)
    }

    static func string(from date: Date) -> String {
        iso.string(from: date)
    }

    static let displayShort: DateFormatter = {
        let f = DateFormatter()
        f.locale = Locale(identifier: "fr_FR")
        f.dateFormat = "d MMM"
        return f
    }()

    static func displayShort(_ isoString: String) -> String {
        guard let date = day(from: isoString) else { return isoString }
        return displayShort.string(from: date)
    }
}
