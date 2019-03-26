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

public struct SlackService {
    public enum Error: Swift.Error, Debuggable {
        case invalidToken
        case invalidChannel

        public var identifier: String {
            return ""
        }

        public var reason: String {
            switch self {
            case .invalidToken:
                return "Invalid token"
            case .invalidChannel:
                return "Invalid channel"
            }
        }
    }

    let requireChannel: String?
    let ci: CIService

    public init(
        requireChannel: String?,
        ci: CIService
    ) {
        self.requireChannel = requireChannel
        self.ci = ci
    }

    public func handle(command: SlackCommand, metadata: SlackCommandMetadata, on worker: Worker) throws -> Future<HTTPResponse> {
        if metadata.token != command.token {
            throw Error.invalidToken
        }
        if let requireChannel = requireChannel, metadata.channel_name != requireChannel {
            throw Error.invalidChannel
        }

        if metadata.text == "help" {
            return try worker.future(result(fromCIResponse: command.help))
        } else {
            return try ci
                .run(command: command.parse(metadata), on: worker)
                .map(result(fromCIResponse:))
        }
    }

    private func result(fromCIResponse response: String) throws -> HTTPResponse {
        return HTTPResponse(
            status: .ok,
            headers: ["Content-Type": "application/json"],
            body: try JSONEncoder().encode(
                [
                    "response_type": "in_channel",
                    "text": response
                ]
            )
        )
    }

}
