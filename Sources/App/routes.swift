import Vapor
import Stevenson

public func routes(
    _ app: Application,
    commands: [SlackCommand]
) throws {
    app.get { req in
        return "It works!"
    }
    
    app.post("github/comment") { (request) -> EventLoopFuture<Response> in
        try app.github.issueComment(on: request, ci: app.ci)
    }

    app.post("api/crp") { (request) -> EventLoopFuture<Response> in
        try CRPProcess.apiRequest(
            request: request,
            github: app.github,
            jira: app.jira,
            slack: app.slack
        )
    }

    commands.forEach { command in
        app.post(command.name) { req -> EventLoopFuture<Response> in
            do {
                return try attempt {
                    try app.slack.handle(command: command, on: req)
                }
            } catch {
                return try SlackService.Response(error: error).encode(for: req)
            }
        }
    }
}
