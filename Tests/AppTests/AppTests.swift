@testable import App
import Stevenson
import Vapor
import XCTest

final class AppTests: XCTestCase {
    static let fakeCommits = [
        "[CNSMR-2044] Commit 1",
        // It's a trap! We don't want it to match "sdk-core" as a ticket reference from the SDK board
        "[CNSMR-1763] Migrate sdk-nhsgp into sdk-core (#8163)",
        "[SDK-4142] Commit 2",
        "[IOSP-123] Update things here and there including in the #SDK",
        "[CNSMR-2045] Commit 3",
        // It's a trap! We don't want it to match "remote-tracking" as a ticket from the (non-existing) REMOTE board
        "Merge remote-tracking branch 'origin/release/babylon/4.4.0' into develop",
        "[IOSP-456] Nothing touching the SDK here",
        "[SDKS-1337] Commit 4",
    ]

    static let fakeVersion = JiraService.Version(
        id: "42",
        projectId: 123,
        name: "Fake 1.2.3",
        description: "Fake Version 1.2.3 for tests",
        startDate: fixedGMTDate(year: 2019, month: 07, day: 10)
    )

    func testReleaseType() {
        typealias ReleaseType = JiraService.CRPIssueFields.ReleaseType
        let expectations: [String: ReleaseType] = [
            "5"      : .major,
            "5.0"    : .major,
            "5.0.0"  : .major,
            "4.1"    : .minor,
            "4.1.0"  : .minor,
            "3.2.1"  : .patch,
            "3.0.1"  : .patch,
            "3.0.0.1": .patch,
        ]
        for (version, expectedType) in expectations {
            XCTAssertEqual(ReleaseType(version: version).id, expectedType.id, "\(version): mismatch")
            XCTAssertEqual(ReleaseType(version: "\(version)-rc1").id, expectedType.id, "\(version)-rc1: mismatch")
        }
    }

    func testJiraDocumentFromCommits() throws {
        let release = try GitHubService.Release(
            repo: GitHubService.Repository(fullName: "company/project", baseBranch: "develop"),
            branch: "release/app/1.2.3"
        )

        let entries = ChangelogSection.makeSections(from: AppTests.fakeCommits, for: release)
        XCTAssertEqual(entries.count, 5)
        XCTAssertEqual(entries[0].board, "CNSMR")
        XCTAssertEqual(entries[0].commits.map { $0.message }, ["[CNSMR-2044] Commit 1", "[CNSMR-1763] Migrate sdk-nhsgp into sdk-core (#8163)", "[CNSMR-2045] Commit 3"])
        XCTAssertEqual(entries[0].commits.map { $0.ticket?.key }, ["CNSMR-2044", "CNSMR-1763", "CNSMR-2045"])
        XCTAssertEqual(entries[1].board, "IOSP")
        XCTAssertEqual(entries[1].commits.map { $0.message }, ["[IOSP-123] Update things here and there including in the #SDK", "[IOSP-456] Nothing touching the SDK here"])
        XCTAssertEqual(entries[1].commits.map { $0.ticket?.key }, ["IOSP-123", "IOSP-456"])
        XCTAssertEqual(entries[2].board, "SDK")
        XCTAssertEqual(entries[2].commits.map { $0.message }, ["[SDK-4142] Commit 2"])
        XCTAssertEqual(entries[2].commits.map { $0.ticket?.key }, ["SDK-4142"])
        XCTAssertEqual(entries[3].board, "SDKS")
        XCTAssertEqual(entries[3].commits.map { $0.message }, ["[SDKS-1337] Commit 4"])
        XCTAssertEqual(entries[3].commits.map { $0.ticket?.key }, ["SDKS-1337"])
        XCTAssertEqual(entries[4].board, nil)
        XCTAssertEqual(entries[4].commits.map { $0.message }, ["Merge remote-tracking branch 'origin/release/babylon/4.4.0' into develop"])
        XCTAssertEqual(entries[4].commits.map { $0.ticket?.key }, [nil])

        let jiraBaseURL = URL(string: "https://babylonpartners.atlassian.net:443")!
        let changelogDoc = JiraService.document(from: entries, jiraBaseURL: jiraBaseURL)

        let crpConfig = RepoMapping.CRP(
            environment: [.appStore, .playStore],
            jiraVersionName: { _ in "Dummy Version 1.2.3" },
            jiraSummary: { _ in "Fake-Publish Dummy App v1.2.3" }
        )
        let issue = JiraService.makeCRPIssue(
            jiraBaseURL: jiraBaseURL,
            crpProjectID: .init(id: "12345"),
            crpConfig: crpConfig,
            release: release,
            changelog: changelogDoc,
            targetDate: fixedGMTDate(year: 2019, month: 10, day: 31)
        )

        addAttachment(name: "Ticket", object: issue)

        XCTAssertEqualJSON(issue, AppTests.expectedTicketJson, "Ticket JSON Mismatch")
    }

    func testFilteredCommitsForSDK() throws {
        let release = try GitHubService.Release(
            repo: GitHubService.Repository(fullName: "company/project", baseBranch: "develop"),
            branch: "release/sdk/1.2.3"
        )

        let entries = ChangelogSection.makeSections(from: AppTests.fakeCommits, for: release)
        XCTAssertEqual(entries.count, 3)
        XCTAssertEqual(entries[0].board, "IOSP")
        XCTAssertEqual(entries[0].commits.map { $0.message }, ["[IOSP-123] Update things here and there including in the #SDK"])
        XCTAssertEqual(entries[0].commits.map { $0.ticket?.key }, ["IOSP-123"]) // but not IOSP-456 :)
        XCTAssertEqual(entries[1].board, "SDK")
        XCTAssertEqual(entries[1].commits.map { $0.message }, ["[SDK-4142] Commit 2"])
        XCTAssertEqual(entries[1].commits.map { $0.ticket?.key }, ["SDK-4142"])
        XCTAssertEqual(entries[2].board, "SDKS")
        XCTAssertEqual(entries[2].commits.map { $0.message }, ["[SDKS-1337] Commit 4"])
        XCTAssertEqual(entries[2].commits.map { $0.ticket?.key }, ["SDKS-1337"])
    }

    func testVersion() throws {
        addAttachment(name: "Version JSON", object: AppTests.fakeVersion)

        let expected = #"""
            {
              "id" : "42",
              "projectId" : 123,
              "startDate" : "2019-07-10",
              "description" : "Fake Version 1.2.3 for tests",
              "name" : "Fake 1.2.3",
              "released" : false
            }
            """#
        XCTAssertEqualJSON(AppTests.fakeVersion, expected, "Version JSON Mismatch")
    }

    func testAddVersion() throws {
        let update = JiraService.VersionAddUpdate(version: AppTests.fakeVersion)
        addAttachment(name: "AddVersion", object: update)

        let expected = #"""
            {
              "update" : {
                "fixVersions" : [
                  {
                    "add" : {
                      "id" : "42",
                      "projectId" : 123,
                      "startDate" : "2019-07-10",
                      "description" : "Fake Version 1.2.3 for tests",
                      "name" : "Fake 1.2.3",
                      "released" : false
                    }
                  }
                ]
              }
            }
            """#

        XCTAssertEqualJSON(update, expected, "Update Request JSON Mismatch")
    }

    func testJiraErrors() throws {
        let decoder = JSONDecoder()

        let errorResponse1 = #"""
            {"errorMessages":["Issue does not exist or you do not have permission to see it.","Some other message"],"errors":{}}
        """#.data(using: .utf8)!

        let error1 = try decoder.decode(JiraService.ServiceError.self, from: errorResponse1)
        XCTAssertEqual(error1.errorMessages, ["Issue does not exist or you do not have permission to see it.", "Some other message"])
        XCTAssertEqual(error1.errors, [:])
        XCTAssertEqual(error1.reason, "[1] Issue does not exist or you do not have permission to see it. [2] Some other message")

        let errorResponse2 = #"""
            {"errorMessages":[],"errors":{"fixVersions":"Field 'fixVersions' cannot be set. It is not on the appropriate screen, or unknown."}}
        """#.data(using: .utf8)!

        let error2 = try decoder.decode(JiraService.ServiceError.self, from: errorResponse2)
        XCTAssertEqual(error2.errorMessages, [])
        XCTAssertEqual(error2.errors, ["fixVersions": "Field 'fixVersions' cannot be set. It is not on the appropriate screen, or unknown."])
        XCTAssertEqual(error2.reason, "fixVersions: Field 'fixVersions' cannot be set. It is not on the appropriate screen, or unknown.")

        let errorResponse3 = #"""
            {"errorMessages":["msg1.","msg2."],"errors":{"key1":"error1.","key2":"error2."}}
        """#.data(using: .utf8)!

        let error3 = try decoder.decode(JiraService.ServiceError.self, from: errorResponse3)
        XCTAssertEqual(error3.reason, "[1] msg1. [2] msg2. [3] key1: error1. [4] key2: error2.")

        let errorResponse4 = #"""
            {"errorMessages":[],"errors":{}}
        """#.data(using: .utf8)!

        let error4 = try decoder.decode(JiraService.ServiceError.self, from: errorResponse4)
        XCTAssertEqual(error4.reason, "Unknown error")
    }

    func testFixVersionReport() {
        let someError = URLError(.badServerResponse)
        let reports: [[JiraService.FixVersionReport]] = [
            [.init(),.init(),.init()],
            [.init(.notInWhitelist(project: "PRJ"))],
            [.init(.releaseCreationFailed(project: "PRJ", error: someError))],
            [
                .init(),
                .init(),
                .init(.updateFixVersionFailed(ticket: "PRJ-123", url: "http://example.jira.org/browse/PRJ-123", error: URLError(.timedOut))),
                .init(),
                .init()
            ],
            [
                .init(),
                .init(.updateFixVersionFailed(ticket: "PRJ-456", url: "http://example.jira.org/browse/PRJ-456", error: URLError(.timedOut))),
                .init()
            ],
            [.init(),.init(),.init(),]
        ]
        let reportsPerProject = reports.map(JiraService.FixVersionReport.init(reports:))
        let consolidated = JiraService.FixVersionReport(reports: reportsPerProject)
        XCTAssertEqual(consolidated.description, """
             • Project `PRJ` is not part of our whitelist for creating JIRA versions
             • Error creating JIRA release in board `PRJ` – \(someError.localizedDescription)
             • Error setting Fix Version field for <http://example.jira.org/browse/PRJ-123|PRJ-123> – Request timed out (-1001)
             • Error setting Fix Version field for <http://example.jira.org/browse/PRJ-456|PRJ-456> – Request timed out (-1001)
            """)
    }
}


// MARK: Test Fixtures

extension AppTests {
    static let expectedTicketJson = #"""
        {
          "fields" : {
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
                                "url" : "https:\/\/babylonpartners.atlassian.net:443\/browse\/CNSMR-1763#icft=CNSMR-1763"
                              }
                            },
                            {
                              "type" : "text",
                              "text" : " Migrate sdk-nhsgp into sdk-core (#8163)"
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
                              "text" : " Commit 3"
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
                      "text" : "IOSP tickets"
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
                                "url" : "https:\/\/babylonpartners.atlassian.net:443\/browse\/IOSP-123#icft=IOSP-123"
                              }
                            },
                            {
                              "type" : "text",
                              "text" : " Update things here and there including in the #SDK"
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
                                "url" : "https:\/\/babylonpartners.atlassian.net:443\/browse\/IOSP-456#icft=IOSP-456"
                              }
                            },
                            {
                              "type" : "text",
                              "text" : " Nothing touching the SDK here"
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
                      "text" : "SDK tickets"
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
                                "url" : "https:\/\/babylonpartners.atlassian.net:443\/browse\/SDK-4142#icft=SDK-4142"
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
                      "text" : "SDKS tickets"
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
                                "url" : "https:\/\/babylonpartners.atlassian.net:443\/browse\/SDKS-1337#icft=SDKS-1337"
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
                },
                {
                  "type" : "heading",
                  "attrs" : {
                    "level" : 3
                  },
                  "content" : [
                    {
                      "type" : "text",
                      "text" : "Other"
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
                              "type" : "text",
                              "text" : "Merge remote-tracking branch 'origin\/release\/babylon\/4.4.0' into develop"
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
            "customfield_11514" : "2019-10-31",
            "customfield_12763" : {
              "id" : "12569"
            },
            "issuetype" : {
              "id" : "11439"
            },
            "project" : {
              "id" : "12345"
            },
            "customfield_12762" : {
              "id" : "12566"
            },
            "customfield_13350" : {
              "type" : "doc",
              "content" : [
                {
                  "type" : "paragraph",
                  "content" : [
                    {
                      "type" : "text",
                      "text" : "Product Changes: \nService Changes: \nBOM:"
                    }
                  ]
                }
              ],
              "version" : 1
            },
            "customfield_12541" : "https:\/\/github.com\/company\/project\/releases\/tag\/app\/1.2.3",
            "customfield_11512" : {
              "type" : "doc",
              "content" : [
                {
                  "type" : "paragraph",
                  "content" : [
                    {
                      "type" : "text",
                      "text" : "Android & iOS native mobile apps PED Test Plan - https://docs.google.com/document/d/1GlvBD7DL0B24WOdky_sCJp3bewmwuHHkYfYcrPWDQEI/edit#heading=h.1jdzrbj14q2r \\nTestRail milestone (automated & manual test runs) -\\nCI branch pipeline (automated unit tests and build) -\\nInternal release notes/QA sign-off -"
                    }
                  ]
                }
              ],
              "version" : 1
            },
            "summary" : "Fake-Publish Dummy App v1.2.3",
            "customfield_12540" : "https:\/\/babylonpartners.atlassian.net:443\/secure\/Dashboard.jspa?selectPageId=15452",
            "customfield_11505" : {
              "accountId" : "5d77d4701e81950d2d821307"
            },
            "customfield_12592" : [
              {
                "id" : "12395"
              },
              {
                "id" : "12394"
              }
            ],
            "customfield_12527" : {
              "id" : "11941"
            },
            "customfield_12794" : {
              "id" : "12653"
            },
            "customfield_12538" : {
              "type" : "doc",
              "content" : [
                {
                  "type" : "paragraph",
                  "content" : [
                    {
                      "type" : "text",
                      "text" : "The headlines for this release are:\\nThere are a number of tickets from the Changelog that are yet to be moved to a completed status or resolution in their respective workflow. Each of these have been reviewed and commented on with why they do not impact the release, yet are in the codebase. These tickets are:"
                    }
                  ]
                }
              ],
              "version" : 1
            }
          }
        }
        """#
}
