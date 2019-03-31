import Vapor

public struct SlackCommand {
    public let name: String
    public let help: String
    let token: String
    let parse: (SlackCommandMetadata) throws -> Command

    public init(
        name: String,
        help: String,
        token: String,
        parse: @escaping (SlackCommandMetadata) throws -> Command
    ) {
        self.name = name
        self.help = help
        self.token = token
        self.parse = parse
    }
}

public struct SlackCommandMetadata: Content {
    public let token: String
    public let channelName: String
    public let text: String

    enum CodingKeys: String, CodingKey {
        case token
        case channelName = "channel_name"
        case text
    }
}

public struct SlackResponse: Content {
    public let response_type = "in_channel"
    public let text: String

    public init(text: String) {
        self.text = text
    }
}

public struct SlackService {
    let requireChannel: String?
    let ci: CIService

    public init(
        requireChannel: String?,
        ci: CIService
    ) {
        self.requireChannel = requireChannel
        self.ci = ci
    }

    public func handle(command: SlackCommand, on request: Request) throws -> Future<Response> {
        let metadata: SlackCommandMetadata = try attempt {
            try request.content.syncDecode(SlackCommandMetadata.self)
        }

        if metadata.token != command.token {
            throw Error.invalidToken
        }
        if let requireChannel = requireChannel, metadata.channelName != requireChannel {
            throw Error.invalidChannel
        }

        if metadata.text == "help" {
            return try SlackResponse(text: command.help)
                .encode(for: request)
        } else {
            return try ci
                .run(command: command.parse(metadata), on: request)
                .map(SlackResponse.init(text:))
                .encode(for: request)
        }
    }
}
