import Vapor

public struct SlackCommand {
    /// Command name
    public let name: String

    /// Command usage instructions
    public let help: String

    /// Channels from which this command is allowed to be triggered.
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
    public let textComponents: [String.SubSequence]
    public let responseURL: String?

    public init(
        token: String,
        channelName: String,
        text: String,
        responseURL: String?
    ) {
        self.token = token
        self.channelName = channelName
        self.text = text
        self.textComponents = text.split(separator: " ")
        self.responseURL = responseURL
    }

    enum CodingKeys: String, CodingKey {
        case token
        case channelName = "channel_name"
        case text
        case responseURL = "response_url"
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self = try SlackCommandMetadata(
            token:          container.decode(String.self, forKey: .token),
            channelName:    container.decode(String.self, forKey: .channelName),
            text:           container.decode(String.self, forKey: .text),
            responseURL:    container.decode(String.self, forKey: .responseURL)
        )
    }
}

public struct SlackResponse: Content {
    public let text: String
    public let visibility: Visibility

    public enum Visibility: String, Content {
        /// Response message visible only to the user who triggered the command
        case user = "ephemeral"
        /// Response message visible to all members of the channel where the command was triggered
        case channel = "in_channel"
    }

    enum CodingKeys: String, CodingKey {
        case text
        case visibility = "response_type"
    }

    public init(_ text: String, visibility: Visibility = .user) {
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

        guard metadata.token == token else {
            throw Error.invalidToken
        }

        guard command.allowedChannels.isEmpty || command.allowedChannels.contains(metadata.channelName) else {
            throw Error.invalidChannel(metadata.channelName, allowed: command.allowedChannels)
        }

        if metadata.text == "help" {
            return try SlackResponse(command.help)
                .encode(for: request)
        } else {
            return try command
                .run(metadata, request)
                .mapIfError { SlackResponse($0.localizedDescription) }
                .encode(for: request)
        }
    }

}

extension Future where T == SlackResponse {
    public func replyLater(
        withImmediateResponse now: SlackResponse,
        responseURL: String?,
        on container: Container
    ) -> Future<SlackResponse> {
        guard let responseURL = responseURL else {
            return container.eventLoop.future(now)
        }

        _ = self
            .mapIfError { SlackResponse($0.localizedDescription) }
            .flatMap { response in
                try container.client()
                    .post(responseURL) {
                        try $0.content.encode(response)
                    }
                    .catchError(.capture())
        }

        return container.eventLoop.future(now)
    }
}
