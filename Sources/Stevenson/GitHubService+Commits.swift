import Foundation
import Vapor

extension GitHubService {
    public struct CommitList: Content {
        let total_commits: Int
        let commits: [Commit]

        func allMessages(includeDetails: Bool) -> [String] {
            return self.commits.map {
                let message = $0.commit.message
                if includeDetails {
                    return message
                } else {
                    return String(message[..<(message.firstIndex(of: "\n") ?? message.endIndex)])
                }
            }
        }
    }

    public struct Commit: Content {
        let sha: String
        let commit: CommitMetaData

        struct CommitMetaData: Content {
            let message: String
        }
    }

    /// `from` and `to` are expected to be commit revisions, typically either a commit SHA or a ref name (e.g. branch or tag)
    public func commitList(
        in repo: Repository,
        from: String,
        to: String,
        on container: Container
    ) throws -> Future<CommitList> {
        let url = URL(string: "/repos/\(repo.fullName)/compare/\(from)...\(to)", relativeTo: baseURL)!
        return try request(.capture()) {
            try container.client().get(url, headers: headers)
        }
    }

    public func changelog(
        for release: Release,
        on container: Container
    ) throws -> Future<[String]> {
        let repo = release.repository
        return try commitList(
            in: repo,
            from: repo.baseBranch,
            to: release.branch,
            on: container
        ).map { $0.allMessages(includeDetails: false) }
    }
}
