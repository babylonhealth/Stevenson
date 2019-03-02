import Vapor
import StevensonCore

/// Called before your application initializes.
public func configure(_ config: inout Config, _ env: inout Environment, _ services: inout Services) throws {
    let router = EngineRouter.default()
    try routes(router)
    services.register(router, as: Router.self)

    // Register middleware
    var middlewares = MiddlewareConfig()
    middlewares.use(ErrorMiddleware.self)
    services.register(middlewares)

    let slackCommands = SlackCommandHandler(
        commands: [
            "/fastlane": fastlane
        ],
        requireChannel: ProcessInfo.processInfo.environment["SLACK_CHANNEL"]
    )
    services.register(slackCommands, as: CommandHandler.self)

    let ci = CircleCIService(
        project: ProcessInfo.processInfo.environment["GITHUB_REPO"]!,
        token: ProcessInfo.processInfo.environment["CIRCLECI_TOKEN"]!,
        defaultBranch: "develop"
    )
    services.register(ci, as: CIService.self)
}
