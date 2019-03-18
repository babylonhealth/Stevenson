import Vapor
import StevensonCore

/// Called before your application initializes.
public func configure(_ config: inout Config, _ env: inout Environment, _ services: inout Services) throws {
    let ci = CircleCIService(
        project: ProcessInfo.processInfo.environment["GITHUB_REPO"]!,
        token: ProcessInfo.processInfo.environment["CIRCLECI_TOKEN"]!,
        defaultBranch: "develop"
    )

    let slack = SlackService(
        commands: [
            fastlane
        ],
        requireChannel: ProcessInfo.processInfo.environment["SLACK_CHANNEL"],
        ci: ci
    )

    let router = EngineRouter.default()
    try routes(router: router, commandHandler: slack)
    services.register(router, as: Router.self)

    var middlewares = MiddlewareConfig()
    middlewares.use(ErrorMiddleware.self)
    services.register(middlewares)
}
