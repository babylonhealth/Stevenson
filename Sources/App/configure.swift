import Vapor
import Stevenson

/// Called before your application initializes.
public func configure(_ config: inout Config, _ env: inout Environment, _ services: inout Services) throws {
    let slack = SlackService(
        token: try attempt { Environment.get(.SLACK_TOKEN) }
    )

    let ci = CircleCIService(
        token: try attempt { Environment.get(.CIRCLECI_TOKEN) }
    )

    let jira = JiraService(
        baseURL: try attempt { Environment.get(.JIRA_HOST).flatMap(URL.init(string:)) },
        username: try attempt { Environment.get(.JIRA_USERNAME) },
        password: try attempt { Environment.get(.JIRA_TOKEN) }
    )

    let github = GitHubService(
        username: try attempt { Environment.get(.GITHUB_USERNAME) },
        token: try attempt { Environment.get(.GITHUB_TOKEN) }
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
