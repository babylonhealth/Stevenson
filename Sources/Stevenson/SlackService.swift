import Vapor

public struct SlackCommand {
    /// Command name
    public let name: String

    /// Command usage instructions
    public let help: String

    /// Channels where command should be allowed.
    /// If empty the command will be allowed in all channels
    public let allowedChannels: Set<String>

    let run: (SlackCommandMetadata, Request) throws -> Future<SlackResponse>

    public init(
        name: String,
        help: String,
        allowedChannels: Set<String>,
        run: @escaping (SlackCommandMetadata, Request) throws -> Future<SlackResponse>
    ) {
        self.name = name
        self.allowedChannels = allowedChannels
        self.help = help
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
    public let text: String
    public let visibility: Visibility

    public enum Visibility: String, Content {
        // response message visible only to the user who triggered the command
        case user = "ephemeral"
        // response message visible to all members of the channel where the command was triggered
        case channel = "in_channel"
    }

    enum CodingKeys: String, CodingKey {
        case text
        case visibility = "response_type"
    }

    public init(_ text: String, visibility: Visibility = .channel) {
        self.text = text
        self.visibility = visibility
    }
}

public struct SlackService {
    let token: String

    public init(token: String) {
        self.token = token
    }

    public func handle(command: SlackCommand, on request: Request) throws -> Future<Response> {
        let metadata: SlackCommandMetadata = try attempt {
            try request.content.syncDecode(SlackCommandMetadata.self)
        }

        if metadata.token != token {
            throw Error.invalidToken
        }
        if !command.allowedChannels.isEmpty && !command.allowedChannels.contains(metadata.channelName) {
            throw Error.invalidChannel
        }

        if metadata.text == "help" {
            return try SlackResponse(command.help)
                .encode(for: request)
        } else {
            return try command
                .run(metadata, request)
                .mapIfError { SlackResponse($0.localizedDescription, visibility: .user) }
                .encode(for: request)
        }
    }
}
