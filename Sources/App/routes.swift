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

    router.post(Commands.fastlane.name) { req in
        return try req.content.decode(SlackCommandMetadata.self).map { metadata in
            try slack.handle(command: Commands.fastlane, metadata: metadata, on: req)
        }
    }
}
