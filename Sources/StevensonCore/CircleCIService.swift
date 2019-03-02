import Vapor

public struct CircleCIService: CIService {
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

    public func run(command: Command, on worker: Worker) -> Future<String> {
        return HTTPClient.connect(
            scheme: .https,
            hostname: hostname,
            on: worker
        ).flatMap { client -> Future<String> in
            let branch = command.branch ?? self.defaultBranch
            let path = "/api/v1.1/project/github/\(self.project)/tree/\(branch)?circle-token=\(self.token)"
            let request = HTTPRequest(
                method: .POST,
                url: path,
                headers: ["Content-Type": "application/json", "Accept": "application/json"],
                body: try JSONEncoder().encode(["build_parameters": command.arguments])
            )
            return client.send(request)
                .flatMap { $0.body.consumeData(on: worker) }
                .map { (data) throws -> String in
                    // move creating response to another service?
                    let decoder = JSONDecoder()
                    decoder.keyDecodingStrategy = .convertFromSnakeCase
                    let buildUrl = try decoder.decode(BuildResponse.self, from: data).buildUrl
                    return "Triggered `\(command.name)` on the `\(branch)` branch.\n\(buildUrl)"
            }
        }
    }
}
