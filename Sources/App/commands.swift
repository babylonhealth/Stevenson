import Foundation
import Vapor
import StevensonCore

extension SlackCommand {
    static let fastlane = { (ci: CIService) in
        SlackCommand(
            name: "fastlane",
            help: """
            Invokes specified lane on specified branch (or develop if not specified).
            Provide options the same way as when invoking lane locally.

            Example:
            `/fastlane test_babylon \(branchOptionPrefix)develop`
            """,
            token: Environment.get("SLACK_TOKEN")!,
            run: { metadata, request in
                let components = metadata.text.components(separatedBy: " ")
                let lane = components[0]
                let options = components.dropFirst().joined(separator: " ")
                let args = ["FASTLANE": lane, "OPTIONS": options]
                let command = Command(name: lane, arguments: args)
                let branch = SlackCommand.branch(fromOptions: components)

                return try ci
                    .run(command: command, branch: branch, on: request)
                    .map {
                        SlackResponse("""
                            Triggered `\(command.name)` on the `\($0.branch)` branch.
                            \($0.buildURL)
                            """
                        )
                }
        })
    }

    private static let branchOptionPrefix = "branch:"

    static let crp = { (jiraService: JiraService, githubService: GitHubService) in
        SlackCommand(
            name: "crp",
            help: """
                Creates a ticket on the CRP board.

                Example:
                `/crp ios release/3.12-nhs111`
                """,
            token: Environment.get("SLACK_TOKEN")!,
            run: { metadata, request in
                let components = metadata.text.components(separatedBy: " ")
                guard components.count >= 2 else {
                    throw SlackService.Error.missingParameter(key: "repo, branch")
                }

                let repoName = components[0]
                guard let repoID = RepoID.find(matching: repoName) else {
                    let all = RepoID.allCases.map({ $0.rawValue }).joined(separator: "|")
                    throw SlackService.Error.invalidParameter(key: "repo", value: repoName, expected: all)
                }

                let branchName = components[1]
                let release = try GitHubService.Release(repository: repoID.repository, branchName: branchName)
                return try githubService.changelog(for: release, on: request)
                    .map { changelog in
                        SlackCommand.makeCRPIssue(
                            repoID: repoID,
                            release: release,
                            changelog: changelog
                        )
                    }
                    .flatMap { issue in
                        try jiraService.create(issue: issue, on: request)
                    }
                    .catchError(.capture())
                    .map { (issue: JiraService.CreatedIssue) -> SlackResponse in
                        SlackResponse("""
                            CRP Ticket #\(issue.id) created.
                            \(issue.url)
                            """
                        )
                }
        })
    }

    private static func branch(fromOptions options: [String]) -> String? {
        let branch = options.dropFirst()
            .first { $0.hasPrefix(branchOptionPrefix) }?
            .dropFirst(branchOptionPrefix.count)
        return branch.map(String.init)
    }

    private static func makeCRPIssue(repoID: RepoID, release: GitHubService.Release, changelog: String) -> JiraService.CRPIssue {
        let isTelus = release.appName?.caseInsensitiveCompare("Telus") == .orderedSame
        let accountablePerson = isTelus ? "eric.schnitzer" : "andreea.papillon"
        let fields = JiraService.CRPIssueFields(
            summary: repoID.jiraSummary(release: release),
            environments: [repoID.environment],
            release: release,
            changelog: changelog,
            accountablePersonName: accountablePerson
        )
        return .init(fields: fields)
    }
}
