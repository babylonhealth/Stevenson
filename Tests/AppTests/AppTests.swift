@testable import App
import Stevenson
import Vapor
import XCTest

final class AppTests: XCTestCase {
    static let fakeCommits = [
        "[ABC-123] Commit 1",
        "[DEF-234] Commit 3",
        "[ABC-456] Commit 2",
        "[DEF-567] Commit 4"
    ]

    func testJiraDocumentFromCommits() throws {
        let release = try GitHubService.Release(
            repo: GitHubService.Repository(fullName: "company/project", baseBranch: "develop"),
            branch: "release/app/1.2.3"
        )

        let entries = ChangelogSection.makeSections(from: AppTests.fakeCommits, for: release)
        XCTAssertEqual(entries.count, 2)
        XCTAssertEqual(entries[0].board, "ABC")
        XCTAssertEqual(entries[0].commits.map { $0.message }, ["[ABC-123] Commit 1", "[ABC-456] Commit 2"])
        XCTAssertEqual(entries[0].commits.map { $0.ticket?.key }, ["ABC-123", "ABC-456"])
        XCTAssertEqual(entries[1].board, "DEF")
        XCTAssertEqual(entries[1].commits.map { $0.message }, ["[DEF-234] Commit 3", "[DEF-567] Commit 4"])
        XCTAssertEqual(entries[1].commits.map { $0.ticket?.key }, ["DEF-234", "DEF-567"])

        let baseURL = URL(string: "https://babylonpartners.atlassian.net:443")!
        let changelogDoc = JiraService.document(from: entries, jiraBaseURL: baseURL)
        
        let encoder = JSONEncoder()
        encoder.outputFormatting = .prettyPrinted
        let jsonData = try encoder.encode(changelogDoc)
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
                      "type" : "inlineCard",
                      "attrs" : {
                        "url" : "https:\\/\\/babylonpartners.atlassian.net:443\\/browse\\/ABC-123#icft=ABC-123"
                      }
                    },
                    {
                      "type" : "text",
                      "text" : " Commit 1"
                    },
                    {
                      "type" : "hardBreak"
                    },
                    {
                      "type" : "inlineCard",
                      "attrs" : {
                        "url" : "https:\\/\\/babylonpartners.atlassian.net:443\\/browse\\/ABC-456#icft=ABC-456"
                      }
                    },
                    {
                      "type" : "text",
                      "text" : " Commit 2"
                    },
                    {
                      "type" : "hardBreak"
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
                      "type" : "inlineCard",
                      "attrs" : {
                        "url" : "https:\\/\\/babylonpartners.atlassian.net:443\\/browse\\/DEF-234#icft=DEF-234"
                      }
                    },
                    {
                      "type" : "text",
                      "text" : " Commit 3"
                    },
                    {
                      "type" : "hardBreak"
                    },
                    {
                      "type" : "inlineCard",
                      "attrs" : {
                        "url" : "https:\\/\\/babylonpartners.atlassian.net:443\\/browse\\/DEF-567#icft=DEF-567"
                      }
                    },
                    {
                      "type" : "text",
                      "text" : " Commit 4"
                    },
                    {
                      "type" : "hardBreak"
                    }
                  ]
                }
              ],
              "version" : 1
            }
            """
        )

        let crpConfig = RepoMapping.CRP(
            environment: .appStore,
            jiraSummary: { _ in "Fake-Publish Dummy App v1.2.3" }
        )
        let issue = JiraService.makeCRPIssue(
            crpConfig: crpConfig,
            release: release,
            changelog: changelogDoc
        )

        let issueData = try encoder.encode(issue)
        let issueJson = String(data: issueData, encoding: .utf8)
        print(issueJson ?? "<nil>")
    }

    static let allTests = [
        ("testJiraDocumentFromCommits", testJiraDocumentFromCommits)
    ]
}
