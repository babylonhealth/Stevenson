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
            - `branch`: release branch name (e.g. `release/<version>`, `release/<app>/<version>`)

            Example:
            `/crp ios \(Option.branch):release/3.13.0`
            """,
            allowedChannels: ["ios-build"],
            run: { metadata, container in
                let components = metadata.text.components(separatedBy: " ")

                guard let repo = components.first else {
                    throw SlackService.Error.missingParameter(key: Option.repo.value)
                }

                guard let repoMapping = RepoMapping.all[repo.lowercased()] else {
                    let all = RepoMapping.all.keys.joined(separator: "|")
                    throw SlackService.Error.invalidParameter(
                        key: Option.repo.value,
                        value: repo,
                        expected: all
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
