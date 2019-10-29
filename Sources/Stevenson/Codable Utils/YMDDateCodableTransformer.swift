import Foundation

public enum YMDDate: TransformerType {
    public static func encode(decodedObject date: Date) throws -> String {
        Self.formatter.string(from: date)
    }

    public static func decode(encodedObject string: String) throws -> Date {
        if let date = Self.formatter.date(from: string) {
            return date
        } else {
            throw InvalidDate(string: string)
        }
    }

    public struct InvalidDate: Error {
        let string: String
    }

    private static var formatter: DateFormatter {
        // Note: ISO8601DateFormatter seem to crash on Linux anyway
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter
    }
}
