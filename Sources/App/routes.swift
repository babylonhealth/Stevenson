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
        try slack.handle(command: Commands.fastlane, request: req.http, on: req)
    }
}
