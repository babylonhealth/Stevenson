@testable import App
import Stevenson
import XCTest

final class AppTests: XCTestCase {
    func testJiraDocumentFromChangelog() throws {
        let entries: [ChangelogSection] = [
            .init(board: "ABC", commits: ["[ABC-123] Commit 1", "[ABC-456] Commit 2"]),
            .init(board: "DEF", commits: ["[DEF-234] Commit 3", "[DEF-234] Commit 4"])
        ]
        let doc = JiraService.document(from: entries)
        let encoder = JSONEncoder()
        encoder.outputFormatting = .prettyPrinted
        let jsonData = try encoder.encode(doc)
        let json = String(data: jsonData, encoding: .utf8)
        XCTAssertEqual(json, """
            {
              "type" : "doc",
              "content" : [
                {
                  "type" : "heading",
                  "attrs" : {
                    "level" : 3
                  },
                  "content" : [
                    {
                      "type" : "text",
                      "text" : "ABC tickets"
                    }
                  ]
                },
                {
                  "type" : "paragraph",
                  "content" : [
                    {
                      "type" : "text",
                      "text" : "ABC-123 Commit 1"
                    },
                    {
                      "type" : "hardbreak"
                    },
                    {
                      "type" : "text",
                      "text" : "ABC-456 Commit 2"
                    }
                  ]
                },
                {
                  "type" : "heading",
                  "attrs" : {
                    "level" : 3
                  },
                  "content" : [
                    {
                      "type" : "text",
                      "text" : "DEF tickets"
                    }
                  ]
                },
                {
                  "type" : "paragraph",
                  "content" : [
                    {
                      "type" : "text",
                      "text" : "DEF-234 Commit 3"
                    },
                    {
                      "type" : "hardbreak"
                    },
                    {
                      "type" : "text",
                      "text" : "DEF-234 Commit 4"
                    }
                  ]
                }
              ],
              "version" : 1
            }
            """
        )
    }

    static let allTests = [
        ("testJiraDocumentFromChangelog", testJiraDocumentFromChangelog)
    ]
}
