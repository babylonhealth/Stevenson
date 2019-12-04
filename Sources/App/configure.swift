import Vapor
import Stevenson

// Use https://babylonpartners.atlassian.net/rest/api/3/project/<ProjectKey> to get the corresponding ID
private let jiraProjects = [
    "ANDRP" : 17264, // Android Platform
    "APPTS" : 16875, // Booking/Appointments
    "AV"    : 16942, // Onboarding and Navigation (ex Core Experience / Avalon)
    "CE"    : 16937, // Consultation Experience
    "CNSMR" : 16968, // Consumer Apps (Native/Core)
    "COREUS": 17127, // Babylon US Core Product
    "CW"    : 16832, // Consumer Web
    "GW"    : 16949, // Triage UI
    // TODO: [IOSP-101/IOSP-147] Re-enable IDM once this board have migrated away from NextGen board
    // "IDM"   : 16903, // Identity Platform / Identity Management
    "IOSP"  : 17263, // iOS Native Apps Platform
    "MS"    : 17233, // Monitor
    "MON"   : 10103, // HealthCheck
    "NRX"   : 16911, // GP@Hand Registrations (ex Enrolment and Integrity)
    "PAR"   : 17098, // Partnerships
    "PRO"   : 16980, // Professional Services
    "PRSCR" : 16840, // Prescriptions
    "SDK"   : 16975, // SDK
    "TEL"   : 16857, // Telus
    // TODO: [IOSP-101/268] Re-enable TEN once this board have migrated away from NextGen board
    // "TEN"   : 16955,
    "TK"    : 17299, // Test Kits
    "WH"    : 17112, // Women's Health
]

/// Called before your application initializes.
public func configure(_ config: inout Config, _ env: inout Environment, _ services: inout Services) throws {
    let logger = PrintLogger()

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
        knownProjects: jiraProjects,
        logger: logger
    )

    let github = GitHubService(
        username: try attempt { Environment.githubUsername },
        token: try attempt { Environment.githubToken }
    )

    let router = EngineRouter.default()
    try routes(
        router: router,
        github: github,
        ci: ci,
        slack: slack,
        commands: [
            .stevenson(ci, jira, github),
            .fastlane(ci),
            .appcenter(ci),
            .testflight(ci),
            .crp(jira, github)
        ]
    )
    services.register(router, as: Router.self)

    var middlewares = MiddlewareConfig()
    middlewares.use(ErrorMiddleware.self)
    services.register(middlewares)
}
