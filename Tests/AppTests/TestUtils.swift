import Foundation
import XCTest

extension XCTestCase {
    #if Xcode
    func addAttachment<T: Encodable>(name: String, object: T) { /* Not available on Linux */ }
    #else
    func addAttachment<T: Encodable>(name: String, object: T) {
        let string = try? String(data: toJSONData(object), encoding: .utf8)
        let attachment = XCTAttachment(string: string ?? "<nil>")
        attachment.name = name
        self.add(attachment)
    }
    #endif
}

func XCTAssertEqualJSON(_ lhs: Data, _ rhs: Data, _ message: String? =  nil, file: StaticString = #file, line: UInt = #line) {
    do {
        // We can't compare plain Data/Strings because the serialisation depends on the machines  we run
        // the tests on (e.g. macOS/Linux) and order of the keys in serialized textual JSON might differ.
        // So instead we compare the NSDictionary version of those. Note that since [String: Any] is not Comparable,
        // We need to rely on JSONSerialiwation and NSDictionary instead to be able to use `==` / `XCAssertEqual`.
        let objectDict = try JSONSerialization.jsonObject(with: lhs, options: []) as? NSDictionary
        let expectedDict = try JSONSerialization.jsonObject(with: rhs, options: []) as? NSDictionary
        XCTAssertEqual(objectDict, expectedDict, message ?? "", file: file, line: line)
    } catch {
        XCTFail("Failed to deserialize JSON data to a dictionary – \(message ?? "")")
    }
}

func XCTAssertEqualJSON<T: Encodable>(_ object: T, _ json: String, _ message: String? =  nil, file: StaticString = #file, line: UInt = #line) {
    do {
        let jsonData = try toJSONData(object)
        let expectedData = json.data(using: .utf8) ?? Data()
        XCTAssertEqualJSON(jsonData, expectedData, message, file: file, line: line)
    } catch {
        XCTFail("Failed to serialize object to JSON – \(message ?? "")")
    }
}

func toJSONData<T: Encodable>(_ object: T) throws -> Data {
    let encoder = JSONEncoder()
    encoder.outputFormatting = .prettyPrinted
    return try encoder.encode(object)
}
