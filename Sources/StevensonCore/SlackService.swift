import Vapor

public typealias SlackCommand = (
    name: String,
    help: String,
    token: String,
    parse: (SlackCommandMetadata) throws -> Command
)

public struct SlackCommandMetadata: Content {
    public let token: String
    public let channel_name: String
    public let text: String
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
        if let requireChannel = requireChannel, metadata.channel_name != requireChannel {
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
