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
                    .map { filter(changelog:$0, for: release) }
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

private func filter(changelog: [String], for release: GitHubService.Release) -> [String] {
    let messages = release.isSDK ? changelog.filter { $0.contains("#SDK") || $0.contains("[SDK-") } : changelog
    // Group the changes by JIRA boards
    let regex = try! NSRegularExpression(pattern: #"\[([A-Z]*)-[0-9]*\]"#, options: [])
    let grouped = Dictionary(grouping: messages) { (message: String) -> String in
        let fullRange = NSRange(message.startIndex..<message.endIndex, in: message)
        let match = regex.firstMatch(in: message, options: [], range: fullRange)
        let jiraBoard = match.flatMap({ Range($0.range(at: 1), in: message) }).map({ String(message[$0]) })
        return jiraBoard ?? "Other"
    }
    return grouped.reduce(into: [], { (accum: inout [String], entry: (key: String, value: [String])) in
        accum.append("## \(entry.key) tickets")
        accum.append("")
        accum.append(contentsOf: entry.value)
        accum.append("")
    })
}
