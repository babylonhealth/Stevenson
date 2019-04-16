import Vapor
import Stevenson

/// Register your application's routes here.
public func routes(
    router: Router,
    slack: SlackService,
    commands: [SlackCommand]
) throws {
    router.get { req in
        return "It works!"
    }

    commands.forEach { command in
        router.post(command.name) { req in
            try attempt {
                try slack.handle(command: command, on: req)
            }
        }
    }
}
