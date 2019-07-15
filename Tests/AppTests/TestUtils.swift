import Foundation
import XCTest

extension XCTestCase {
    #if Xcode
    func addAttachment<T: Encodable>(name: String, object: T) {
        let string = try? String(data: toJSONData(object), encoding: .utf8)
        let attachment = XCTAttachment(string: string ?? "<nil>")
        attachment.name = name
        self.add(attachment)
    }
    #else
    func addAttachment<T: Encodable>(name: String, object: T) { /* Not available on Linux nor outside Xcode */ }
    #endif
}

func XCTAssertEqualJSON(_ lhs: Data, _ rhs: Data, _ message: String? =  nil, file: StaticString = #file, line: UInt = #line) {
    do {
        // We can't compare plain Data/Strings because the serialisation depends on the machines  we run
        // the tests on (e.g. macOS/Linux) and order of the keys in serialised textual JSON might differ.
        // So instead we compare the NSDictionary version of those. Note that since [String: Any] is not Comparable,
        // We need to rely on JSONSerialization and NSDictionary to be able to use `==` / `XCAssertEqual`.
        let lhsDict = try JSONSerialization.jsonObject(with: lhs, options: []) as? NSDictionary
        let rhsDict = try JSONSerialization.jsonObject(with: rhs, options: []) as? NSDictionary
        XCTAssertEqual(lhsDict, rhsDict, message ?? "", file: file, line: line)
    } catch {
        XCTFail("Failed to deserialize JSON data to a dictionary – \(message ?? "")")
    }
}

func XCTAssertEqualJSON<T: Encodable>(_ object: T, _ json: String, _ message: String? =  nil, file: StaticString = #file, line: UInt = #line) {
    do {
        let objectData = try toJSONData(object)
        let expectedData = json.data(using: .utf8) ?? Data()
        XCTAssertEqualJSON(objectData, expectedData, message, file: file, line: line)
    } catch {
        XCTFail("Failed to serialize object to JSON – \(message ?? "")")
    }
}

func toJSONData<T: Encodable>(_ object: T) throws -> Data {
    let encoder = JSONEncoder()
    encoder.outputFormatting = .prettyPrinted
    return try encoder.encode(object)
}
