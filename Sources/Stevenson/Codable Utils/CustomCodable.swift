import Foundation

public protocol CodableTransformer {
    associatedtype DecodedType
    associatedtype TypeForCoding: Codable
    static func encode(decodedObject: DecodedType) throws -> TypeForCoding
    static func decode(encodedObject: TypeForCoding) throws -> DecodedType
}

@propertyWrapper
public struct CustomCodable<Transformer: CodableTransformer> {
    public var wrappedValue: Transformer.DecodedType
    public init(wrappedValue: Transformer.DecodedType) {
        self.wrappedValue = wrappedValue
    }
}

extension CustomCodable: Codable {
    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        let encoded = try container.decode(Transformer.TypeForCoding.self)
        self.wrappedValue = try Transformer.decode(encodedObject: encoded)
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        let encoded = try Transformer.encode(decodedObject: self.wrappedValue)
        try container.encode(encoded)
    }
}
