import Foundation
import Vapor

extension GitHubService {
    public func branch(
        in repo: Repository,
        name: String,
        on container: Container
    ) throws -> Future<GitHubService.Reference> {
        let url = URL(string: "/repos/\(repo.fullName)/git/refs/heads/\(name)", relativeTo: baseURL)!
        return try request(.capture()) {
            try container.client().get(url, headers: headers)
        }
    }

    public func createBranch(
        in repo: Repository,
        name: String,
        from ref: GitHubService.Reference,
        on container: Container
    ) throws -> Future<GitHubService.Reference> {
        let url = URL(string: "/repos/\(repo.fullName)/git/refs", relativeTo: baseURL)!
        return try request(.capture()) {
            try container.client().post(url, headers: headers) {
                try $0.content.encode(["ref": "refs/heads/\(name)", "sha": ref.sha])
            }
        }
    }
}
