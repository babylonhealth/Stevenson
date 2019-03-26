import Vapor
import StevensonCore

/// Register your application's routes here.
public func routes(
    router: Router,
    slack: SlackService
) throws {
    router.get { req in
        return "It works!"
    }

    router.post(Commands.fastlane.name) { req -> Future<HTTPResponse> in
        return try req.content.decode(SlackCommandMetadata.self).flatMap { metadata in
            try slack.handle(command: Commands.fastlane, metadata: metadata, on: req)
        }
    }
}
