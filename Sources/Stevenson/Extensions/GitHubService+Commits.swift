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

    /// Return the list of commits between a release branch and the last matching tag.
    ///
    /// This will search for the last GitHub Release / tag matching the same app as the Release,
    /// then get the list of commit messages (only the first line of each commit) between that tag
    /// (representing the last version) and the release branch (representing the upcomming release)
    ///
    /// - Parameters:
    ///   - release: The release we want to extract the changelog for
    ///   - container: The Vapor Container to run the requests on
    /// - Returns: List of commits between the release branch and the last tag matching the release.appName
    public func changelog(
        for release: Release,
        on container: Container
    ) throws -> Future<[String]> {
        return try releases(in: release.repository, on: container).flatMap { (tags: [String]) -> Future<[String]> in
            guard let latestAppTag = tags.first(where: release.isMatchingTag) else {
                throw ServiceError(message: "Failed to find previous tag matching '\(release.appName)/*' to build the CHANGELOG")
            }
            let allCommits = try self.commitList(
                in: release.repository,
                from: latestAppTag,
                to: release.branch,
                on: container
            )
            return allCommits.map { $0.allMessages(includeDetails: false) }
        }
    }
}
