import Vapor

public struct CircleCIService {
    private let baseURL = URL(string: "https://circleci.com")!
    private let headers: HTTPHeaders = [
        "Content-Type": "application/json",
        "Accept": "application/json"
    ]

    public let token: String

    public init(token: String) {
        self.token = token
    }

    struct BuildRequest: Content {
        let buildParameters: [String: String]

        enum CodingKeys: String, CodingKey {
            case buildParameters = "build_parameters"
        }
    }

    public struct BuildResponse: Content {
        public let branch: String
        public let buildURL: String

        enum CodingKeys: String, CodingKey {
            case branch
            case buildURL = "build_url"
        }
    }

    private func buildURL(project: String, branch: String) -> URL {
        return URL(
            string: "/api/v1.1/project/github/\(project)/tree/\(branch)?circle-token=\(token)",
            relativeTo: baseURL
        )!
    }

    public func run(
        command: Command,
        project: String,
        branch: String,
        on container: Container
    ) throws -> Future<BuildResponse> {
        let url = buildURL(project: project, branch: branch)
        return try request(.capture()) {
            try container.client().post(url, headers: headers) {
                try $0.content.encode(BuildRequest(buildParameters: command.arguments))
            }
        }
    }
}
