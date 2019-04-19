import Vapor

/// Creates an instance of `Application`. This is called from `main.swift` in the run target.
public func app(_ env: Environment) throws -> Application {
    var config = Config.default()
    var env = env
    var services = Services.default()
    try configure(&config, &env, &services)
    let app = try Application(config: config, environment: env, services: services)
    return app
}

extension Environment {
    enum Key: String {
        case SLACK_TOKEN
        case SLACK_CHANNEL
        case GITHUB_USERNAME
        case GITHUB_TOKEN
        case CIRCLECI_TOKEN
        case JIRA_HOST
        case JIRA_USERNAME
        case JIRA_TOKEN
    }

    static func get(_ key: Key) -> String? {
        return get(key.rawValue)
    }
}
