import Vapor
import Stevenson

private let jiraProjects = [
    "NRX"  : 16911, // Enrolment and Integrity
    "CE"   : 16937, // Consultation Experience
    "AV"   : 16942, // Core Experience / Avalon
    "CW"   : 16832, // Consumer Web
    "CNSMR": 16968, // Consumer Apps (Native/Core)
    "MON"  : 10103, // HealthCheck
    "GW"   : 16949, // Triage UI
    "PRSCR": 16840, // Prescriptions
    "SDK"  : 16975, // SDK
    "APPTS": 16875, // Booking/Appointments
    "TEL"  : 16857, // Telus
    "PRO"  : 16980, // Professional Services
    "PAR"  : 17098, // Partnerships
    "MN"   : 17031, // Monitor
    "TES"  : 17074, // Tests & Kits
    "WH"   : 17112, // Women's Health
    "IDM"  : 16903, // Identity Platform / Identity Management
    "CM"   : 16920, // Condition Management
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
