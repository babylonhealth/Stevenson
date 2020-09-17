import Vapor
import Stevenson

/// Register your application's routes here
public func routes(
    _ app: Application,
    github: GitHubService,
    ci: CircleCIService,
    slack: SlackService,
    jira: JiraService,
    commands: [SlackCommand]
) throws {
    app.get { req in
        return "It works!"
    }
    
    app.post("github/comment") { (request) -> EventLoopFuture<Response> in
        try github.issueComment(on: request, ci: ci)
    }

    app.post("api/crp") { (request) -> EventLoopFuture<Response> in
        try CRPProcess.apiRequest(request: request, github: github, jira: jira, slack: slack)
    }

    commands.forEach { command in
        app.post(command.name) { req -> EventLoopFuture<Response> in
            do {
                return try attempt {
                    try slack.handle(command: command, on: req)
                }
            } catch {
                return try SlackService.Response(error: error).encode(for: req)
            }
        }
    }
}
