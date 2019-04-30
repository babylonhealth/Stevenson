import Vapor
import Stevenson

struct CreateReleaseBranchCommand: Vapor.Command {
    let arguments: [CommandArgument] = []
    let options: [CommandOption] = []
    let help: [String] = []

    // TODO: refactor into slack command as well
    func run(using context: CommandContext) throws -> EventLoopFuture<Void> {
        let github: GitHubService = try context.container.make()
        // TODO: accept repository as parameter
        return try github.branch(
            in: RepoMapping.ios.repository,
            name: RepoMapping.ios.repository.baseBranch,
            on: context.container
            )
            .flatMap { head in
                try github.createBranch(
                    in: RepoMapping.ios.repository,
                    // TODO: detect branch name based on tags
                    name: "test_release/1.2.3",
                    from: head,
                    on: context.container
                )
            }
            // TODO: send slack message to the webhook?
            .map { print("Success: \($0)") }
            .mapIfError { print("Error: \($0)") }
    }
}

/// Called before your application initializes.
public func configure(_ config: inout Config, _ env: inout Environment, _ services: inout Services) throws {
    let slack = SlackService(
        token: try attempt { Environment.slackToken }
    )

    let ci = CircleCIService(
        token: try attempt { Environment.circleciToken }
    )

    let jira = JiraService(
        baseURL: try attempt { Environment.jiraBaseURL.flatMap(URL.init(string:)) },
        username: try attempt { Environment.jiraUsername },
        password: try attempt { Environment.jiraToken }
    )

    let github = GitHubService(
        username: try attempt { Environment.githubUsername },
        token: try attempt { Environment.githubToken }
    )
    services.register(github, as: GitHubService.self)

    let router = EngineRouter.default()
    try routes(router: router, slack: slack, commands: [
        .fastlane(ci),
        .hockeyapp(ci),
        .testflight(ci),
        .crp(jira, github)
    ])
    services.register(router, as: Router.self)

    var commandConfig = CommandConfig.default()
    // This command is scheduled to be run every Monday at 0:00
    commandConfig.use(CreateReleaseBranchCommand(), as: "create_release_branch")
    services.register(commandConfig)

    var middlewares = MiddlewareConfig()
    middlewares.use(ErrorMiddleware.self)
    services.register(middlewares)
}
