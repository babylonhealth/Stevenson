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
                    .catchError(.capture())
                    .map { ChangelogSection.makeSections(from: $0, for: release) }
                    .map { JiraService.document(from: $0) }
                    .map { changelog in
                        jira.makeCRPIssue(
                            repoMapping: repoMapping,
                            release: release,
                            changelog: changelog
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


struct ChangelogSection {
    let board: String?
    let commits: [(message: String, ticket: JiraService.TicketID?)]

    /// Filters the CHANGELOG entries then orders and formats the CHANGELOG text
    ///
    /// - Parameters:
    ///   - commits: The list of commits gathered between last release and current one
    ///   - release: The release for which to build the CHANGELOG text for
    /// - Returns: The text containing the filtered and formatted CHANGELOG, grouped and ordered by jira board
    static func makeSections(from commits: [String], for release: GitHubService.Release) -> [ChangelogSection] {
        // Only keep SDK commits if release is for SDK
        let filteredMessages = release.isSDK ? commits.filter { $0.contains("#SDK") || $0.contains("[SDK-") } : commits
        let parsedMessages = filteredMessages.map { (message: $0, ticket: JiraService.TicketID(from: $0)) }

        // Group then sort the changes by JIRA boards (unclassified last)
        return Dictionary(grouping: parsedMessages) { $0.ticket?.board }
            .sorted { e1, e2 in e1.key ?? "ZZZ" < e2.key ?? "ZZZ" }
            .map(ChangelogSection.init)
    }
}
