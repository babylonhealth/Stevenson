import Vapor
import Stevenson

/// Register your application's routes here.
public func routes(
    router: Router,
    github: GitHubService,
    ci: CircleCIService,
    slack: SlackService,
    commands: [SlackCommand]
) throws {
    router.get { req in
        return "It works!"
    }

    router.post("github/comment") { (request) -> Future<Response> in
        try github.issueComment(on: request, ci: ci)
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
