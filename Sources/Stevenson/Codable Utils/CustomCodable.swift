import Foundation

public protocol TransformerType {
    associatedtype DecodedType
    associatedtype EncodedType
    static func encode(decodedObject: DecodedType) throws -> EncodedType
    static func decode(encodedObject: EncodedType) throws -> DecodedType
}

@propertyWrapper
public struct CustomCodable<T: TransformerType> {
    public var wrappedValue: T.DecodedType
    public init(wrappedValue: T.DecodedType) {
        self.wrappedValue = wrappedValue
    }
}

extension CustomCodable: Decodable where T.EncodedType: Decodable {
    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        let encoded = try container.decode(T.EncodedType.self)
        self.wrappedValue = try T.decode(encodedObject: encoded)
    }
}

extension CustomCodable: Encodable where T.EncodedType: Encodable {
    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        let encoded = try T.encode(decodedObject: self.wrappedValue)
        try container.encode(encoded)
    }
}
