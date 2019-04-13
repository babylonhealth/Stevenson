import Foundation
import Vapor

public struct GitHubService {
    private let baseUrl = "https://api.github.com:443"
    private let headers: HTTPHeaders

    public init(username: String, token: String) {
        let base64Auth = Data("\(username):\(token)".utf8).base64EncodedString(options: [])
        self.headers = [
            "Authorization": "Basic \(base64Auth)",
            "Accept": "application/json"
        ]
    }
}

public extension GitHubService {
    public typealias CommitRef = String

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
        let commit: CommitInfo

        struct CommitInfo: Content {
            let message: String
        }
    }

    public func commitList(in repo: Repository, from: CommitRef, to: CommitRef, on request: Request) throws -> Future<CommitList> {
        let fullURL = self.baseUrl + "/repos/\(repo.fullName)/compare/\(from)...\(to)"
        return try request.client()
            .get(fullURL, headers: self.headers)
            .catchError(.capture())
            .flatMap {
                try $0.content.decode(CommitList.self)
            }
            .catchError(.capture())
    }

    func changelog(for release: Release, on request: Request) throws -> Future<String> {
        let repo = release.repository
        return try commitList(in: repo, from: repo.baseBranch, to: release.branch, on: request)
            .map {
                $0.allMessages(includeDetails: false).joined(separator: "\n")
        }
    }
}
