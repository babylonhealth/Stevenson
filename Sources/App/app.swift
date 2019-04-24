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
    static let slackToken       = Environment.get("SLACK_TOKEN")
    static let slackChannel     = Environment.get("SLACK_CHANNEL")
    static let githubUsername   = Environment.get("GITHUB_USERNAME")
    static let githubToken      = Environment.get("GITHUB_TOKEN")
    static let circleciToken    = Environment.get("CIRCLECI_TOKEN")
    static let jiraBaseURL      = Environment.get("JIRA_BASEURL")
    static let jiraUsername     = Environment.get("JIRA_USERNAME")
    static let jiraToken        = Environment.get("JIRA_TOKEN")
}
