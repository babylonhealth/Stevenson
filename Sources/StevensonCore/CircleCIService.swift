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

    public struct BuildResponse: Codable {
        public let buildUrl: String
    }

    public func run(command: Command, on worker: Worker) throws -> Future<String> {
        let branch = command.arguments[CircleCIService.branchArgument] ?? self.defaultBranch
        let path = "/api/v1.1/project/github/\(project)/tree/\(branch)?circle-token=\(token)"
        let request = HTTPRequest(
            method: .POST,
            url: path,
            headers: ["Content-Type": "application/json", "Accept": "application/json"],
            body: try attempt {
                try JSONEncoder().encode(["build_parameters": command.arguments])
            }
        )

        return HTTPClient
            .connect(scheme: .https, hostname: hostname, on: worker)
            .catchError(.capture())
            .flatMap { client in
                client.send(request)
                    .catchError(.capture())
                    .flatMap { $0.body.consumeData(on: worker) }
                    .attemptMap { data in
                        let decoder = JSONDecoder()
                        decoder.keyDecodingStrategy = .convertFromSnakeCase
                        let buildUrl = try decoder.decode(BuildResponse.self, from: data).buildUrl
                        return "Triggered `\(command.name)` on the `\(branch)` branch.\n\(buildUrl)"
                }
        }
    }
}
