import Foundation

@propertyWrapper
public struct YMDDate {
    public var wrappedValue: Date
    public init(wrappedValue: Date) {
        self.wrappedValue = wrappedValue
    }
}

extension YMDDate: Codable {
    public struct InvalidDate: Error {
        let string: String
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        let string = try container.decode(String.self)
        if let date = Self.formatter.date(from: string) {
            self.wrappedValue = date
        } else {
            throw InvalidDate(string: string)
        }
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        let string = Self.formatter.string(from: wrappedValue)
        try container.encode(string)
    }
    
    private static var formatter: DateFormatter {
        // Note: ISO8601DateFormatter seem to crash on Linux anyway
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter
    }
}
