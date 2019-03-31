import Vapor

public struct SlackCommand {
    public let name: String
    public let help: String
    let token: String
    let run: (SlackCommandMetadata, Request) throws -> Future<SlackResponse>

    public init(
        name: String,
        help: String,
        token: String,
        run: @escaping (SlackCommandMetadata, Request) throws -> Future<SlackResponse>
    ) {
        self.name = name
        self.help = help
        self.token = token
        self.run = run
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

    public init(_ text: String) {
        self.text = text
    }
}

public struct SlackService {
    let requireChannel: String?

    public init(
        requireChannel: String?
    ) {
        self.requireChannel = requireChannel
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
            return try SlackResponse(command.help)
                .encode(for: request)
        } else {
            return try command.run(metadata, request)
                .encode(for: request)
        }
    }
}
