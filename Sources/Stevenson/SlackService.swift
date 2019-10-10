import Vapor

public struct SlackCommand {
    /// Command name
    public let name: String

    /// Command usage instructions
    public let help: String

    /// Channels from which this command is allowed to be triggered.
    /// If empty the command will be allowed in all channels
    public let allowedChannels: Set<String>

    /// Closure that performs the actual action of the command.
    /// If subCommands are provided then it first will try to select approapraite sub command
    /// by the first word in the command text, and if it finds one then this command will be executed,
    /// otherwise this closure is called
    public let run: (SlackCommandMetadata, Request) throws -> Future<SlackResponse>

    public init(
        name: String,
        help: String,
        allowedChannels: Set<String>,
        subCommands: [String: SlackCommand] = [:],
        run: @escaping (SlackCommandMetadata, Request) throws -> Future<SlackResponse>
    ) {
        self.name = name
        self.allowedChannels = allowedChannels
        self.help = help
        self.run = { (metadata, container) throws -> Future<SlackResponse> in
            let subCommandName = String(metadata.textComponents[0])
            guard let subCommand = subCommands[subCommandName] else {
                return try run(metadata, container)
            }

            if metadata.textComponents[1] == "help" {
                return container.future(SlackResponse(subCommand.help))
            } else {
                let metadata = SlackCommandMetadata(
                    token: metadata.token,
                    channelName: metadata.channelName,
                    command: metadata.command,
                    text: metadata.textComponents.dropFirst().joined(separator: " "),
                    responseURL: metadata.responseURL
                )
                return try subCommand.run(metadata, container)
            }
        }
    }
}

public struct SlackCommandMetadata: Content {
    public let token: String
    public let channelName: String
    public let command: String
    public let text: String
    public let textComponents: [String.SubSequence]
    public let responseURL: String?

    public init(
        token: String,
        channelName: String,
        command: String,
        text: String,
        responseURL: String?
    ) {
        self.token = token
        self.channelName = channelName
        self.command = command
        self.text = text
        self.textComponents = text.split(separator: " ")
        self.responseURL = responseURL
    }

    enum CodingKeys: String, CodingKey {
        case token
        case channelName = "channel_name"
        case command
        case text
        case responseURL = "response_url"
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self = try SlackCommandMetadata(
            token:          container.decode(String.self, forKey: .token),
            channelName:    container.decode(String.self, forKey: .channelName),
            command:        container.decode(String.self, forKey: .command),
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
        return try request.content
            .decode(SlackCommandMetadata.self)
            .catchError(.capture())
            .flatMap { [token] metadata in
                guard metadata.token == token else {
                    throw Error.invalidToken
                }
                
                guard command.allowedChannels.isEmpty || command.allowedChannels.contains(metadata.channelName) else {
                    throw Error.invalidChannel(metadata.channelName, allowed: command.allowedChannels)
                }
                
                if metadata.text == "help" {
                    return request.future(SlackResponse(command.help))
                } else {
                    return try command.run(metadata, request)
                }
            }
            .catchError(.capture())
            .mapIfError { SlackResponse(error: $0) }
            .encode(for: request)
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
            .mapIfError { SlackResponse(error: $0) }
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
