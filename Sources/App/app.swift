import Vapor

#warning("TODO delete this file")

///// Creates an instance of `Application`. This is called from `main.swift` in the run target.
//public func app(_ env: Environment) throws -> Application {
//    var config = Config.default()
//    var env = env
//    var services = Services.default()
//    try configure(&config, &env, &services)
//    let app = try Application(config: config, environment: env, services: services)
//    return app
//}
//
//extension Environment {
//    /// Verification Token (see SlackBot App settings)
//    static let slackToken       = Environment.get("SLACK_TOKEN")
//    /// Bot User OAuth Access Token (see SlackBot App settings)
//    static let slackOAuthToken  = Environment.get("SLACK_OAUTH_TOKEN")
//    /// GitHub Bot Username
//    static let githubUsername   = Environment.get("GITHUB_USERNAME")
//    /// GitHub Bot Access Token
//    static let githubToken      = Environment.get("GITHUB_TOKEN")
//    /// CircleCI Access Token
//    static let circleciToken    = Environment.get("CIRCLECI_TOKEN")
//    /// JIRA Base URL, e.g. "https://yourorg.atlassian.net"
//    static let jiraBaseURL      = Environment.get("JIRA_BASEURL")
//    /// JIRA Bot Username
//    static let jiraUsername     = Environment.get("JIRA_USERNAME")
//    /// JIRA Bot Access Token
//    static let jiraToken        = Environment.get("JIRA_TOKEN")
//}
