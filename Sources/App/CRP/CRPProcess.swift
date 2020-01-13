import Foundation
import Vapor
import Stevenson

enum CRPProcess {
    enum Option: String {
        case repo
        case branch
        case skipTicket
        case skipFixVersion

        func get<T: Decodable>(from request: Request) throws -> T {
            guard let result = request.query[T.self, at: self.rawValue] else {
                throw CRPProcess.Error.missingParameter(self.rawValue)
            }
            return result
        }
    }

    enum Error: Swift.Error {
        case invalidParameter(key: String, value: String, expected: String)
        case missingParameter(String)
    }

    static func apiRequest(request: Request, github: GitHubService, jira: JiraService) throws -> Future<Response> {
        let repo: String = try Option.repo.get(from: request)
        let branch: String = try Option.branch.get(from: request)
        let skipTicket: Bool = (try? Option.skipTicket.get(from: request)) ?? false
        let skipFixVersion: Bool = (try? Option.skipFixVersion.get(from: request)) ?? false

        guard let repoMapping = RepoMapping.all[repo.lowercased()] else {
            throw CRPProcess.Error.invalidParameter(
                key: Option.repo.rawValue,
                value: repo,
                expected: RepoMapping.all.keys.joined(separator: "|")
            )
        }

        let release = try GitHubService.Release(
            repo: repoMapping.repository,
            branch: branch
        )

        return try github.changelog(for: release, on: request)
            .catchError(.capture())
            .flatMap { (commitMessages: [String]) -> Future<(JiraService.CreatedIssue?, JiraService.FixedVersionReport?)> in

                let jiraVersionName = repoMapping.crp.jiraVersionName(release)
                let changelogSections = ChangelogSection.makeSections(from: commitMessages, for: release)

                // Create CRP ticket, unless skipped
                let createTicket: Future<JiraService.CreatedIssue?>
                if skipTicket {
                    createTicket = request.future(nil)
                } else {
                    // Create CRP Issue
                    let crpIssue = JiraService.makeCRPIssue(
                        jiraBaseURL: jira.baseURL,
                        crpProjectID: JiraService.crpProjectID,
                        crpConfig: repoMapping.crp,
                        release: release,
                        changelog: jira.document(from: changelogSections)
                    )

                    createTicket = try jira.create(issue: crpIssue, on: request)
                        .map { Optional.some($0) }
                        .catchError(.capture())
                }

                return createTicket
                    .flatMap { (crpIssue: JiraService.CreatedIssue?) -> Future<(JiraService.CreatedIssue?, JiraService.FixedVersionReport?)> in
                        guard !skipFixVersion else {
                            return request.future( (crpIssue, nil) )
                        }
                        // Create JIRA versions on each board then set Fixed Versions to that new version on each board's ticket included in Changelog
                        return try jira.createAndSetFixedVersions(
                            changelogSections: changelogSections,
                            versionName: jiraVersionName,
                            on: request
                        ).map { (crpIssue, Optional.some($0)) }
                }
            }
            .catchError(.capture())
            .map { (crpIssue, report) in
                var json: [String: AnyCodable] = [:]
                if let ticket = crpIssue {
                    json["ticket"] = AnyCodable([
                        "key": ticket.key,
                        "id": ticket.id,
                        "url": "\(jira.baseURL)/browse/\(ticket.key)"
                    ])
                }
                if let report = report {
                    json["success"] = AnyCodable(report.messages.isEmpty)
                    json["messages"] = AnyCodable(report.messages)
                }
                let response = Response(using: request)
                try response.content.encode(json, as: .json)
                return response
            }
    }
}

extension CRPProcess.Error: Debuggable {
    var identifier: String {
        switch self {
        case .invalidParameter(key: let key, value: _, expected: _):
            return "crp.invalidparameter.\(key)"
        case .missingParameter(let key):
            return "crp.missingparameter.\(key)"
        }
    }

    var reason: String {
        switch self {
        case let .invalidParameter(key: key, value: value, expected: expected):
            return #"Invalid value for parameter `\#(key)`: expected "\#(expected)", got "\#(value)"."#
        case .missingParameter(let key):
            return "Missing value for parameter `\(key)`."
        }
    }
}
