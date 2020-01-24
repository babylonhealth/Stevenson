import Vapor
import Stevenson

/// Register your application's routes here.
public func routes(
    router: Router,
    github: GitHubService,
    ci: CircleCIService,
    slack: SlackService,
    jira: JiraService,
    commands: [SlackCommand]
) throws {
    router.get { req in
        return "It works!"
    }

    router.post("github/comment") { (request) -> Future<Response> in
        try github.issueComment(on: request, ci: ci)
    }

    router.post("api/crp") { (request) -> Future<Response> in
        try CRPProcess.apiRequest(request: request, github: github, jira: jira, slack: slack)
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
