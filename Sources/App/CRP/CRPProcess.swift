import Foundation
import Vapor
import Stevenson

/**
 For detailed documentation of this part of the code, see: [Implementation Details documentation in private repo](https://github.com/babylonhealth/babylon-ios/blob/develop/Documentation/Process/Release%20process/CRP-Bot-ImplementationDetails.md#executing-the-crp-process)
*/
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
        let jiraVersionName = repoMapping.crp.jiraVersionName(release)

        return try github.changelog(for: release, on: request)
            .catchError(.capture())
            .flatMap { (commitMessages: [String]) -> Future<JiraService.CreatedIssue> in

                let changelogSections = ChangelogSection.makeSections(from: commitMessages, for: release)

                // Create CRP Issue
                let crpIssue = JiraService.makeCRPIssue(
                    jiraBaseURL: jira.baseURL,
                    crpProjectID: JiraService.crpProjectID,
                    crpConfig: repoMapping.crp,
                    release: release,
                    changelog: jira.document(from: changelogSections)
                )

                let crpResponse = try jira.create(issue: crpIssue, on: request)
                    .catchError(.capture())

                // Spawn a separate Future once CRP created, to trigger the "Fix Version dance" in the background
                _ = crpResponse.flatMap { _ -> Future<Response> in
                    try jira.createAndSetFixVersions(
                        changelogSections: changelogSections,
                        versionName: jiraVersionName,
                        on: request
                    )
                    .catchError(.capture())
                    .flatMap { (report: JiraService.FixVersionReport) -> Future<Response> in
                        let status = report.statusText(releaseName: jiraVersionName)
                        let message = SlackMessage(channelID: channelID, text: status, attachments: report.asSlackAttachments())
                        return try slack.post(message: message, on: request)
                            .catchError(.capture())
                    }
                }

                return crpResponse
            }
            .flatMap { crpIssue -> Future<JiraService.CreatedIssue> in
                let message = "✅ CRP Ticket created: <\(jira.browseURL(issue: crpIssue))|\(crpIssue.key)>"
                return try slack.post(message: SlackMessage(channelID: channelID, text: message), on: request)
                    .map { _ in crpIssue }
                    .mapIfError { _ in crpIssue }
            }
            .map { crpIssue in
                let json: [String: String] = [
                    "key": crpIssue.key,
                    "id": crpIssue.id,
                    "url": jira.browseURL(issue: crpIssue),
                ]
                let response = Response(using: request)
                try response.content.encode(json, as: .json)
                return response
            }
    }
}

extension JiraService.FixVersionReport {
    func asSlackAttachments() -> [SlackMessage.Attachment] {
        return self.errors.map { error -> SlackMessage.Attachment in
            switch error {
            case .notInWhitelist: return .warning(error.description)
            default: return .error(error.description)
            }
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

