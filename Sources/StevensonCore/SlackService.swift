import Vapor

public typealias SlackCommand = (
    name: String,
    help: String,
    token: String,
    parse: (SlackCommandMetadata) throws -> Command
)

public struct SlackCommandMetadata: Decodable {
    public let token: String
    public let channelName: String
    public let text: String
}

public struct SlackService: CommandHandler {
    public enum Error: Swift.Error, Debuggable {
        case unknownCommand(String)
        case invalidCommand(String)

        public var identifier: String {
            return ""
        }

        public var reason: String {
            switch self {
            case let .unknownCommand(cmd):
                return "Unknown command `\(cmd)`."
            case let .invalidCommand(reason):
                return "Invalid command: \(reason)"
            }
        }
    }

    let registry: [String: SlackCommand]
    let requireChannel: String?
    let ci: CIService

    public init(
        commands: [SlackCommand],
        requireChannel: String?,
        ci: CIService
    ) {
        self.registry = .init(uniqueKeysWithValues: commands.map { ($0.name, $0) })
        self.requireChannel = requireChannel
        self.ci = ci
    }

    public func handle(commandFrom request: HTTPRequest, on worker: Worker) throws -> EventLoopFuture<HTTPResponse> {
        let (slackCommand, content) = try metadata(from: request)

        if content.text == "help" {
            return try worker.future(result(fromCIResponse: slackCommand.help))
        } else {
            return try ci
                .run(command: slackCommand.parse(content), on: worker)
                .map(result(fromCIResponse:))
        }
    }

    private func metadata(from request: HTTPRequest) throws -> (SlackCommand, SlackCommandMetadata) {
        let name = request.url.path
        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        let data = request.body.data ?? Data()
        let content = try decoder.decode(SlackCommandMetadata.self, from: data)
        guard let slackCommand = registry[name] else {
            throw Error.unknownCommand(name)
        }
        if content.token != slackCommand.token {
            throw Error.invalidCommand("Invalid token")
        }
        if let requireChannel = requireChannel, content.channelName != requireChannel {
            throw Error.invalidCommand("Invalid channel")
        }
        return (slackCommand, content)
    }

    private func result(fromCIResponse response: String) throws -> HTTPResponse {
        return HTTPResponse(
            status: .ok,
            body: try JSONEncoder().encode(
                [
                    "response_type": "in_channel",
                    "text": response
                ]
            )
        )
    }

}
