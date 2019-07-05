@testable import App
import Stevenson
import XCTest

final class AppTests: XCTestCase {
    func testJiraDocumentFromCommits() throws {

        let commits = [
            "[ABC-123] Commit 1",
            "[DEF-234] Commit 3",
            "[ABC-456] Commit 2",
            "[DEF-567] Commit 4"
        ]
        let release = try GitHubService.Release(
            repo: GitHubService.Repository(fullName: "company/project", baseBranch: "develop"),
            branch: "release/app/1.2.3"
        )

        let entries = ChangelogSection.makeSections(from: commits, for: release)
        XCTAssertEqual(entries.count, 2)
        XCTAssertEqual(entries[0].board, "ABC")
        XCTAssertEqual(entries[0].commits.map { $0.message }, ["[ABC-123] Commit 1", "[ABC-456] Commit 2"])
        XCTAssertEqual(entries[0].commits.map { $0.ticket?.key }, ["ABC-123", "ABC-456"])
        XCTAssertEqual(entries[1].board, "DEF")
        XCTAssertEqual(entries[1].commits.map { $0.message }, ["[DEF-234] Commit 3", "[DEF-567] Commit 4"])
        XCTAssertEqual(entries[1].commits.map { $0.ticket?.key }, ["DEF-234", "DEF-567"])


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
                      "text" : "DEF-567 Commit 4"
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
        ("testJiraDocumentFromCommits", testJiraDocumentFromCommits)
    ]
}
