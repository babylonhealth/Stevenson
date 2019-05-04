import Foundation
import Vapor

public struct GitHubService: Service {
    public let baseURL = URL(string: "https://api.github.com:443")!
    public let headers: HTTPHeaders

    public init(username: String, token: String) {
        var headers = HTTPHeaders()
        headers.add(name: HTTPHeaderName.accept, value: MediaType.json.description)
        headers.basicAuthorization = BasicAuthorization(username: username, password: token)
        self.headers = headers
    }
}

extension GitHubService {
    public struct Repository {
        public let fullName: String
        public let baseBranch: String
        /// Release tags for this repository should match this regular expression 
        /// and should capture version number in the first capture group.
        public let releaseTag: String

        public init(
            fullName: String,
            baseBranch: String,
            releaseTag: String = "^([0-9]+.[0-9]+.[0-9]+)$"
        ) {
            self.fullName = fullName
            self.baseBranch = baseBranch
            self.releaseTag = releaseTag
        }
    }

    public struct Reference: Decodable {
        public let sha: String

        enum CodingKeys: CodingKey {
            case object
            case sha
        }

        public init(from decoder: Decoder) throws {
            let container = try decoder
                .container(keyedBy: CodingKeys.self)
                .nestedContainer(keyedBy: CodingKeys.self, forKey: .object)

            self.sha = try container.decode(String.self, forKey: .sha)
        }
    }

    public struct Release {
        public let repository: Repository
        public let branch: String
        public let appName: String?
        public let version: String

        public init(repository: Repository, branch: String, appName: String?, version: String) {
            self.repository = repository
            self.branch = branch
            self.appName = appName
            self.version = version
        }
    }
}

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

    public func releases(
        in repo: Repository,
        on container: Container
    ) throws -> Future<[String]> {
        struct Response: Content {
            let tag_name: String
        }
        let url = URL(string: "/repos/\(repo.fullName)/releases?per_page=100", relativeTo: baseURL)!
        return try request(.capture()) {
            try container.client().get(url, headers: headers)
            }
            .map { (response: [Response]) -> [String] in
                response.map { $0.tag_name }
        }
    }
}
