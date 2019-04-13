import Vapor
import Stevenson

/// Called before your application initializes.
public func configure(_ config: inout Config, _ env: inout Environment, _ services: inout Services) throws {
    let ci = CircleCIService(
        project: try attempt { Environment.get("GITHUB_REPO") },
        token: try attempt { Environment.get("CIRCLECI_TOKEN") },
        defaultBranch: "develop"
    )

    let slack = SlackService(
        requireChannel: Environment.get("SLACK_CHANNEL")
    )

    let router = EngineRouter.default()
    try routes(router: router, slack: slack, commands: [
        .fastlane(ci)
    ])
    services.register(router, as: Router.self)

    var middlewares = MiddlewareConfig()
    middlewares.use(ErrorMiddleware.self)
    services.register(middlewares)
}
