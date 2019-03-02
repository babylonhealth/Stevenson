import Vapor

public typealias SlackCommand = (
    help: String,
    token: String,
    parser: (SlackCommandMetadata) throws -> Command
)

public struct SlackCommandMetadata: Decodable {
    public let token: String
    public let channelName: String
    public let text: String
}

public struct SlackCommandHandler: CommandHandler {
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

    public init(commands: [String: SlackCommand], requireChannel: String?) {
        self.registry = commands
        self.requireChannel = requireChannel
    }

    public func command(from request: HTTPRequest) throws -> Command {
        let name = request.url.path
        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        let data = request.body.data ?? Data()
        let content = try decoder.decode(SlackCommandMetadata.self, from: data)
        guard let reg = registry[name] else {
            throw Error.unknownCommand(name)
        }
        if content.token != reg.token {
            throw Error.invalidCommand("Invalid token")
        }
        if let requireChannel = requireChannel, content.channelName != requireChannel {
            throw Error.invalidCommand("Invalid channel")
        }

        if content.text == Command.helpCommandName {
            return Command.help(text: reg.help)
        }
        return try reg.parser(content)
    }

    public func result(from response: String) throws -> HTTPResponse {
        return HTTPResponse(
            status: .ok,
            body: try JSONEncoder().encode([
                "response_type": "in_channel",
                "text": response
                ])
        )
    }

}

public extension Command {
    public static let helpCommandName = "help"
    public static let helpCommandText = "helpText"

    public static func help(text: String) -> Command {
        return Command(
            name: Command.helpCommandName,
            arguments: [Command.helpCommandText: text],
            branch: nil
        )
    }
}
