import Vapor

public struct CircleCIService: CIService {
    public let project: String
    public let token: String
    public let defaultBranch: String

    public init(project: String, token: String, defaultBranch: String) {
        self.project = project
        self.token = token
        self.defaultBranch = defaultBranch
    }

    struct BuildRequest: Content {
        let buildParameters: [String: String]

        enum CodingKeys: String, CodingKey {
            case buildParameters = "build_parameters"
        }
    }

    private func buildURL(branch: String?) -> String {
        return "https://circleci.com/api/v1.1/project/github/\(project)/tree/\(branch ?? defaultBranch)"
    }

    public func run(
        command: Command,
        branch: String?,
        on request: Request
    ) throws -> Future<BuildResponse> {
        return try request.client()
            .post(buildURL(branch: branch), headers: ["Accept": "application/json"]) {
                try $0.query.encode(["circle-token": token])
                try $0.content.encode(BuildRequest(buildParameters: command.arguments))
            }
            .catchError(.capture())
            .flatMap {
                try $0.content.decode(BuildResponse.self)
            }
            .catchError(.capture())
    }
}
