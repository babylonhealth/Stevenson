import Vapor
import Stevenson

private let jiraProjects = [
    // TODO: Provide list of all the projects on which Stevenson is allowed to create versions
    "FCTP": 17165
]

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
        password: try attempt { Environment.jiraToken },
        knownProjects: jiraProjects
    )

    let github = GitHubService(
        username: try attempt { Environment.githubUsername },
        token: try attempt { Environment.githubToken }
    )

    let router = EngineRouter.default()
    try routes(router: router, slack: slack, commands: [
        .fastlane(ci),
        .hockeyapp(ci),
        .testflight(ci),
        .crp(jira, github)
    ])
    services.register(router, as: Router.self)

    var middlewares = MiddlewareConfig()
    middlewares.use(ErrorMiddleware.self)
    services.register(middlewares)
}
