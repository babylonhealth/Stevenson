import Foundation
import Vapor
import Stevenson

extension SlackCommand {
    static let crp = { (jira: JiraService, github: GitHubService) in
        SlackCommand(
            name: "crp",
            help: """
            Creates a ticket on the CRP board from specified release branch.

            Parameters:
            - project identifier (e.g: `ios`, `android`)
            - `branch`: release branch name (typically `release/<app>/<version>`, e.g. `release/babylon/4.1.0`)

            Example:
            `/crp ios \(Option.branch.value):release/babylon/4.1.0`
            """,
            allowedChannels: ["ios-launchpad"],
            run: { metadata, container in
                guard let repo = metadata.textComponents.first else {
                    throw SlackService.Error.missingParameter(key: Option.repo.value)
                }

                guard let repoMapping = RepoMapping.all[repo.lowercased()] else {
                    throw SlackService.Error.invalidParameter(
                        key: Option.repo.value,
                        value: String(repo),
                        expected: RepoMapping.all.keys.joined(separator: "|")
                    )
                }

                guard let branch = metadata.value(forOption: .branch) else {
                    throw SlackService.Error.missingParameter(key: Option.branch.value)
                }

                let release = try GitHubService.Release(
                    repo: repoMapping.repository,
                    branch: branch
                )

                return try github.changelog(for: release, on: container)
                    .map { changelog in
                        jira.makeCRPIssue(
                            repoMapping: repoMapping,
                            release: release,
                            changelog: changelog.joined(separator: "\n")
                        )
                    }
                    .flatMap { issue in
                        try jira.create(issue: issue, on: container)
                    }
                    .catchError(.capture())
                    .map { issue in
                        SlackResponse("""
                            ✅ CRP Ticket \(issue.key) created.
                            \(jira.baseURL)/browse/\(issue.key)
                            """,
                            visibility: .channel
                        )
                    }.replyLater(
                        withImmediateResponse: SlackResponse("🎫 Creating ticket...", visibility: .channel),
                        responseURL: metadata.responseURL,
                        on: container
                )
        })
    }
}
