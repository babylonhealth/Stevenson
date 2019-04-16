import Vapor
import StevensonCore

/// Called before your application initializes.
public func configure(_ config: inout Config, _ env: inout Environment, _ services: inout Services) throws {
    let slack = SlackService(
        requireChannel: Environment.get("SLACK_CHANNEL")
    )

    let ci = CircleCIService(
        project: try attempt { Environment.get("GITHUB_REPO_IOS") },
        token: try attempt { Environment.get("CIRCLECI_TOKEN") },
        defaultBranch: "develop"
    )

    let jira = JiraService(
        host: try attempt { Environment.get("JIRA_HOST") },
        username: try attempt { Environment.get("JIRA_USERNAME") },
        password: try attempt { Environment.get("JIRA_TOKEN") }
    )

    let github = GitHubService(
        username: try attempt { Environment.get("GITHUB_USERNAME") },
        token: try attempt { Environment.get("GITHUB_TOKEN") }
    )

    let router = EngineRouter.default()
    try routes(router: router, slack: slack, commands: [
        .fastlane(ci),
        .crp(jira, github)
    ])
    services.register(router, as: Router.self)

    var middlewares = MiddlewareConfig()
    middlewares.use(ErrorMiddleware.self)
    services.register(middlewares)
}
