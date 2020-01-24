import Foundation
import Vapor
import Stevenson

enum CRPProcess {
    enum Option: String {
        case repo
        case branch
        case slack_channel_id

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

    static func apiRequest(request: Request, github: GitHubService, jira: JiraService, slack: SlackService) throws -> Future<Response> {
        let repo: String = try Option.repo.get(from: request)
        let branch: String = try Option.branch.get(from: request)
        let channelID: String = try Option.slack_channel_id.get(from: request)

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
            .flatMap { (commitMessages: [String]) -> Future<(JiraService.CreatedIssue, Response)> in

                let jiraVersionName = repoMapping.crp.jiraVersionName(release)
                let changelogSections = ChangelogSection.makeSections(from: commitMessages, for: release)

                // Create CRP Issue
                let crpIssue = JiraService.makeCRPIssue(
                    jiraBaseURL: jira.baseURL,
                    crpProjectID: JiraService.crpProjectID,
                    crpConfig: repoMapping.crp,
                    release: release,
                    changelog: jira.document(from: changelogSections)
                )

                let ticketCreated = try jira.create(issue: crpIssue, on: request)
                    .catchError(.capture())
                    .flatMap { crpIssue -> Future<(JiraService.CreatedIssue, Response)> in
                        let message = "CRP Ticket created: <\(jira.browseURL(issue: crpIssue))|\(crpIssue.key)>"
                        return try slack.postMessage(message, channelID: channelID, on: request)
                            .catchError(.capture())
                            .map { (crpIssue, $0) }
                    }

                // Spawn a separate Future to trigger the "Fix Version dance" in the background
                _ = ticketCreated.flatMap { (_, _) in
                    try jira.createAndSetFixVersions(
                        changelogSections: changelogSections,
                        versionName: jiraVersionName,
                        on: request
                    )
                    .catchError(.capture())
                    .flatMap { (report: JiraService.FixVersionReport) -> Future<Response> in
                        let message = report.fullReportText(releaseName: jiraVersionName)
                        return try slack.postMessage(message, channelID: channelID, on: request)
                            .catchError(.capture())
                    }
                }

                return ticketCreated
            }
            .catchError(.capture())
            .map { (crpIssue, slackResponse) in
                let json: [String: String] = [
                    "key": crpIssue.key,
                    "id": crpIssue.id,
                    "url": jira.browseURL(issue: crpIssue),
                    "slack_notification": slackResponse.http.description
                ]
                let response = Response(using: request)
                try response.content.encode(json, as: .json)
                return response
            }
    }
}

extension JiraService.FixVersionReport {
    func fullReportText(releaseName: String) -> String {
        if messages.isEmpty {
            return "✅ Successfully added '\(releaseName)' in the 'Fix Version' field of all tickets"
        } else {
            return """
                ❌ Some errors occurred when trying to add \(releaseName) in the 'Fix Version' field of some tickets.
                Please double-check those tickets, you might need to fix them manually if needed.

                \(self.description)"
                """
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

