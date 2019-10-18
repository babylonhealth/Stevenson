import Vapor
import Stevenson

/// Register your application's routes here.
public func routes(
    router: Router,
    github: GitHubService,
    slack: SlackService,
    commands: [SlackCommand]
) throws {
    router.get { req in
        return "It works!"
    }

    router.post("github") { (request) -> Future<Response> in
        return try HTTPResponse(status: .ok).encode(for: request)
    }

    commands.forEach { command in
        router.post(command.name) { req -> Future<Response> in
            do {
                return try attempt {
                    try slack.handle(command: command, on: req)
                }
            } catch {
                return try SlackResponse(error: error).encode(for: req)
            }
        }
    }
}
