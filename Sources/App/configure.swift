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
    "COVIDBUGS": 17459, // COVID-19 hotfix bugs
    "CW"    : 16832, // Consumer Web
    "ETA"   : 17369, // Engagement Tribe - Activate - TO BE REMOVED ONCE MIGRATED TO EXPCORE
    "ETR"   : 17372, // Engagement Tribe - Retain - TO BE REMOVED AFTER 4.21.0 CUT
    "EXPCORE"   : 17372, // Experience Tribe - Core Apps
    "GW"    : 16949, // Triage UI
    "HC"    : 17251, // HealthCheck (next-gen)
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
    "RM"    : 17403,  // Real-Time Matching
    "SA"    : 17439, // SaaS App
    "SDK"   : 16975, // SDK
    "SDKS"  : 17288, // SDK UI (next-gen)
    "TC"    : 17353, // Triage Comprehension (next-gen)
    "TCN"   : 17431, // Triage comprehension (new)
    "TEL"   : 16857, // Telus
    "TK"    : 17299, // Test Kits
    "TM"    : 17343, // Triage Metrics (next-gen)
    "UNDANDINF"   : 17335, // Understand and Inform (next-gen)
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
