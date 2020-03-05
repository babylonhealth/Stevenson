import Vapor
import Stevenson

// Use https://babylonpartners.atlassian.net/rest/api/3/project/<ProjectKey> to get the corresponding ID
private let jiraProjects = [
    "ACP"   : 17420, // Assistant Chat Platform
    "AND"   : 13700, // Android Engineering
    "ANDRP" : 17264, // Android Platform
    "APPTS" : 16875, // Booking/Appointments
    "AV"    : 16942, // Onboarding and Navigation (ex Core Experience / Avalon)
    "CE"    : 16937, // Consultation Experience
    "CNSMR" : 16968, // Consumer Apps (Native/Core)
    "COCO"  : 17344, // Continuous Compliance
    "COREUS": 17127, // Babylon US Core Product
    "CW"    : 16832, // Consumer Web
    "ETA"   : 17369, // Engagement Tribe - Activate
    "ETR"   : 17372, // Engagement Tribe - Retain
    "GW"    : 16949, // Triage UI
    "HC"    : 17251, // HealthCheck (next-gen)
    // TODO: [IOSP-101/IOSP-147] Re-enable IDM once this board have migrated away from NextGen board
    // "IDM"   : 16903, // Identity Platform / Identity Management
    "IDP"   : 17228, // Identity Access Management
    "IOSP"  : 17263, // iOS Native Apps Platform
    "MC"    : 17006, // Member Communications (next-gen)
    "MS"    : 17233, // Monitor
    "MON"   : 10103, // HealthCheck
    "NRX"   : 16911, // GP@Hand Registrations (ex Enrolment and Integrity)
    "PAR"   : 17098, // Partnerships
    "PRO"   : 16980, // Professional Services
    "PRSCR" : 16840, // Prescriptions
    "REFER" : 17244, // Referrals (next-gen)
    "SDK"   : 16975, // SDK
    "TC"    : 17353, // Triage Comprehension (next-gen)
    "TEL"   : 16857, // Telus
    // TODO: [IOSP-101/268] Re-enable TEN once this board have migrated away from NextGen board
    // "TEN"   : 16955,
    "TK"    : 17299, // Test Kits
    "TM"    : 17343, // Triage Metrics (next-gen)
    "WH"    : 17112, // Women's Health
]

/// Called before your application initializes.
public func configure(_ config: inout Config, _ env: inout Environment, _ services: inout Services) throws {
    let logger = PrintLogger()

    let slack = SlackService(
        verificationToken: try attempt { Environment.slackToken },
        oauthToken: try attempt { Environment.slackOAuthToken }
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
        jira: jira,
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

    // Some services (like JIRA) might need a slower client which handles rate-limiting APIs and quotas
    let slowClient = SlowClient()
    services.register(slowClient)
}
