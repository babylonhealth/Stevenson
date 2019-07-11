@testable import App
import Stevenson
import Vapor
import XCTest

final class AppTests: XCTestCase {
    static let fakeCommits = [
        "[CNSMR-2044] Commit 1",
        "[CRP-4141] Commit 3",
        "[CNSMR-2045] Commit 2",
        "[CRP-4142] Commit 4"
    ]

    func testJiraDocumentFromCommits() throws {
        let release = try GitHubService.Release(
            repo: GitHubService.Repository(fullName: "company/project", baseBranch: "develop"),
            branch: "release/app/1.2.3"
        )

        let entries = ChangelogSection.makeSections(from: AppTests.fakeCommits, for: release)
        XCTAssertEqual(entries.count, 2)
        XCTAssertEqual(entries[0].board, "CNSMR")
        XCTAssertEqual(entries[0].commits.map { $0.message }, ["[CNSMR-2044] Commit 1", "[CNSMR-2045] Commit 2"])
        XCTAssertEqual(entries[0].commits.map { $0.ticket?.key }, ["CNSMR-2044", "CNSMR-2045"])
        XCTAssertEqual(entries[1].board, "CRP")
        XCTAssertEqual(entries[1].commits.map { $0.message }, ["[CRP-4141] Commit 3", "[CRP-4142] Commit 4"])
        XCTAssertEqual(entries[1].commits.map { $0.ticket?.key }, ["CRP-4141", "CRP-4142"])

        let jiraBaseURL = URL(string: "https://babylonpartners.atlassian.net:443")!
        let changelogDoc = JiraService.document(from: entries, jiraBaseURL: jiraBaseURL)
        
        let encoder = JSONEncoder()
        encoder.outputFormatting = .prettyPrinted

        #if Xcode
        let changelogJsonData = try encoder.encode(changelogDoc)
        let changelogJson = String(data: changelogJsonData, encoding: .utf8)
        add(attachment(name: "Changelog JSON", string: changelogJson))
        #endif

        let crpConfig = RepoMapping.CRP(
            environment: .appStore,
            jiraVersionName: { _ in "Dummy Version 1.2.3" },
            jiraSummary: { _ in "Fake-Publish Dummy App v1.2.3" }
        )
        let issue = JiraService.makeCRPIssue(
            jiraBaseURL: jiraBaseURL,
            crpConfig: crpConfig,
            release: release,
            changelog: changelogDoc
        )

        let issueData = try encoder.encode(issue)

        #if Xcode
        let issueJson = String(data: issueData, encoding: .utf8)
        add(attachment(name: "Ticket", string: issueJson))
        #endif

        let expectedTicketDict: NSDictionary? = try {
            // Depending on the platform/machine we run this test on, the hashing and thus order of the keys
            // in the serialised JSON can differ between the machine where the fixture was generated and the one
            // where the test is executed. So we need to compare dictionaries, not textual representations
            let encodedData = AppTests.expectedTicketJson.data(using: .utf8) ?? Data()
            return try JSONSerialization.jsonObject(with: encodedData, options: []) as? NSDictionary
        }()
        let issueDict = try JSONSerialization.jsonObject(with: issueData, options: []) as? NSDictionary

        XCTAssertTrue(issueDict == expectedTicketDict)
    }

    #if Xcode
    private func attachment(name: String, string: String?) -> XCTAttachment {
        let attachment = XCTAttachment(string: string ?? "<nil>")
        attachment.name = name
        return attachment
    }
    #endif
}


// MARK: Test Fixtures

extension AppTests {
    static let expectedTicketJson = #"""
        {
          "fields" : {
            "customfield_12538" : {
              "type" : "doc",
              "content" : [
                {
                  "type" : "paragraph",
                  "content" : [
                    {
                      "type" : "text",
                      "text" : "TBD"
                    }
                  ]
                }
              ],
              "version" : 1
            },
            "customfield_12540" : "https:\/\/babylonpartners.atlassian.net:443\/secure\/Dashboard.jspa?selectPageId=15452",
            "issuetype" : {
              "id" : "11439"
            },
            "customfield_12592" : [
              {
                "id" : "12395"
              }
            ],
            "summary" : "Fake-Publish Dummy App v1.2.3",
            "customfield_12527" : {
              "id" : "11941"
            },
            "customfield_12537" : {
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
                      "text" : "CNSMR tickets"
                    }
                  ]
                },
                {
                  "type" : "bulletList",
                  "content" : [
                    {
                      "type" : "listItem",
                      "content" : [
                        {
                          "type" : "paragraph",
                          "content" : [
                            {
                              "type" : "inlineCard",
                              "attrs" : {
                                "url" : "https:\/\/babylonpartners.atlassian.net:443\/browse\/CNSMR-2044#icft=CNSMR-2044"
                              }
                            },
                            {
                              "type" : "text",
                              "text" : " Commit 1"
                            }
                          ]
                        }
                      ]
                    },
                    {
                      "type" : "listItem",
                      "content" : [
                        {
                          "type" : "paragraph",
                          "content" : [
                            {
                              "type" : "inlineCard",
                              "attrs" : {
                                "url" : "https:\/\/babylonpartners.atlassian.net:443\/browse\/CNSMR-2045#icft=CNSMR-2045"
                              }
                            },
                            {
                              "type" : "text",
                              "text" : " Commit 2"
                            }
                          ]
                        }
                      ]
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
                      "text" : "CRP tickets"
                    }
                  ]
                },
                {
                  "type" : "bulletList",
                  "content" : [
                    {
                      "type" : "listItem",
                      "content" : [
                        {
                          "type" : "paragraph",
                          "content" : [
                            {
                              "type" : "inlineCard",
                              "attrs" : {
                                "url" : "https:\/\/babylonpartners.atlassian.net:443\/browse\/CRP-4141#icft=CRP-4141"
                              }
                            },
                            {
                              "type" : "text",
                              "text" : " Commit 3"
                            }
                          ]
                        }
                      ]
                    },
                    {
                      "type" : "listItem",
                      "content" : [
                        {
                          "type" : "paragraph",
                          "content" : [
                            {
                              "type" : "inlineCard",
                              "attrs" : {
                                "url" : "https:\/\/babylonpartners.atlassian.net:443\/browse\/CRP-4142#icft=CRP-4142"
                              }
                            },
                            {
                              "type" : "text",
                              "text" : " Commit 4"
                            }
                          ]
                        }
                      ]
                    }
                  ]
                }
              ],
              "version" : 1
            },
            "customfield_11512" : {
              "type" : "doc",
              "content" : [
                {
                  "type" : "paragraph",
                  "content" : [
                    {
                      "type" : "text",
                      "text" : "TBD"
                    }
                  ]
                }
              ],
              "version" : 1
            },
            "project" : {
              "id" : "13402"
            },
            "customfield_12541" : "https:\/\/github.com\/company\/project\/releases\/tag\/app\/1.2.3",
            "customfield_11505" : {
              "name" : "andreea.papillon"
            }
          }
        }
        """#
}
