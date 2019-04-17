import Foundation
import Vapor
import Stevenson

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
                Creates a ticket on the CRP board from specified release branch.

                Example:
                `/crp ios branch:release/3.13.0`
                """,
            token: Environment.get("SLACK_TOKEN")!,
            run: { metadata, request in
                let components = metadata.text.components(separatedBy: " ")

                guard let repoName = components.first else {
                    throw SlackService.Error.missingParameter(key: "repo")
                }

                guard let repoMapping = RepoMapping.all[repoName.lowercased()] else {
                    let all = RepoMapping.all.keys.joined(separator: "|")
                    throw SlackService.Error.invalidParameter(key: "repo", value: repoName, expected: all)
                }

                guard let branchName = branch(fromOptions: components) else {
                    throw SlackService.Error.missingParameter(key: "branch")
                }
                let release = try makeGitHubRelease(repo: repoMapping.repository, branch: branchName)
                return try githubService.changelog(for: release, on: request)
                    .map { changelog in
                        makeCRPIssue(
                            repoMapping: repoMapping,
                            release: release,
                            changelog: changelog
                        )
                    }
                    .flatMap { issue in
                        try jiraService.create(issue: issue, on: request)
                    }
                    .catchError(.capture())
                    .map { issue in
                        SlackResponse("""
                            CRP Ticket \(issue.key) created.
                            https://\(jiraService.host)/browse/\(issue.key)
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

    private static func makeGitHubRelease(repo: GitHubService.Repository, branch: String) throws -> GitHubService.Release {
        let branchComponents = branch.components(separatedBy: "/")
        // [CNSMR-1319] TODO: Use a config file to parametrise branch format
        guard branchComponents.count > 1, ["release", "hotfix"].contains(branchComponents[0]) else {
            throw SlackService.Error.invalidParameter(key: "branch", value: branch, expected: "release or hotfix branch")
        }
        let (appName, version): (String?, String)
        if branchComponents.count == 2 {
            // in the form of "release/1.2.3" or "hotfix/1.2.3"
            appName = nil
            version = branchComponents[1]
        } else if branchComponents.count == 3 {
            // in the form of "release/appName/1.2.3" or "hotfix/appName/1.2.3"
            appName = branchComponents[1]
            version = branchComponents[2]
        } else {
            throw SlackService.Error.invalidParameter(key: "branch", value: branch, expected: "(release|hotfix)/<app>/<version>")
        }

        return GitHubService.Release(
            repository: repo,
            branch: branch,
            appName: appName,
            version: version
        )
    }

    private static func makeCRPIssue(repoMapping: RepoMapping, release: GitHubService.Release, changelog: String) -> JiraService.CRPIssue {
        // [CNSMR-1319] TODO: Use a config file to parametrise accountable person
        let isTelus = release.appName?.caseInsensitiveCompare("Telus") == .orderedSame
        let accountablePerson = isTelus ? "eric.schnitzer" : "andreea.papillon"
        // Remove brackets around JIRA ticket names so that it's recognized by JIRA as a ticket reference
        // eg replace "[CNSMR-123] Do this" with "CNSMR-123 Do this"
        let cleanChangelog = changelog.replacingOccurrences(of: "\\[([A-Z]+-[0-9]+)\\]", with: "$1", options: [.regularExpression], range: nil)
        let fields = JiraService.CRPIssueFields(
            summary: repoMapping.jiraSummary(release),
            environments: [repoMapping.environment],
            release: release,
            changelog: cleanChangelog,
            accountablePersonName: accountablePerson
        )
        return JiraService.CRPIssue(fields: fields)
    }
}
