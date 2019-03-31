import Vapor

public struct CircleCIService: CIService {
    public static let branchArgument = "branch"

    public let hostname = "circleci.com"
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

    struct BuildResponse: Content {
        let buildURL: String

        enum CodingKeys: String, CodingKey {
            case buildURL = "build_url"
        }
    }

    public func run(command: Command, on worker: Request) throws -> Future<String> {
        let buildRequest = BuildRequest(buildParameters: command.arguments)
        let branch = command.arguments[CircleCIService.branchArgument] ?? self.defaultBranch
        let path = "/api/v1.1/project/github/\(project)/tree/\(branch)"
        let url = "https://\(hostname)\(path)"

        return try worker.client()
            .post(url, headers: ["Accept": "application/json"]) {
                try $0.query.encode(["circle-token": token])
                try $0.content.encode(buildRequest)
            }
            .catchError(.capture())
            .flatMap {
                try $0.content.decode(BuildResponse.self)
            }
            .catchError(.capture())
            .map {
                "Triggered `\(command.name)` on the `\(branch)` branch.\n\($0.buildURL)"
        }
    }
}
