import Vapor
import Stevenson

private let jiraProjects = [
    "APPTS" : 16875, // Booking/Appointments
    "AV"    : 16942, // Core Experience / Avalon
    "CE"    : 16937, // Consultation Experience
    // TODO: [CNSMR-2402] Re-enable CM board once they've migrated all their tickets from private instance to main one
    // "CM"    : 16920, // Condition Management
    "CNSMR" : 16968, // Consumer Apps (Native/Core)
    "COREUS": 17127, // Babylon US Core Product
    "CW"    : 16832, // Consumer Web
    "GW"    : 16949, // Triage UI
    // TODO: [CNSMR-2402] Re-enable IDM and MN once those boards have migrated to use the standard setup for their JIRA fields
    // "IDM"   : 16903, // Identity Platform / Identity Management
    // "MN"    : 17031, // Monitor –
    "MON"   : 10103, // HealthCheck
    "NRX"   : 16911, // Enrolment and Integrity
    "PAR"   : 17098, // Partnerships
    "PRO"   : 16980, // Professional Services
    "PRSCR" : 16840, // Prescriptions
    "SDK"   : 16975, // SDK
    "TEL"   : 16857, // Telus
    "TES"   : 17074, // Tests & Kits
    "WH"    : 17112, // Women's Health
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
