import Vapor

extension JiraService {
    public struct Project: Equatable {
        public struct JIRATransactionsIds: Equatable {
            let done: Int
            let awaitingBuild: Int
            let peerReview: Int
            let inProgress: Int

            static let `default` = JIRATransactionsIds(done: 201, awaitingBuild: 141, peerReview: 131, inProgress: 121)
        }
        public let prefix: String
        public let transactionIds: JIRATransactionsIds

        // In order to get the transitions ids use this HTTP Request
        // GET https://babylonpartners.atlassian.net/rest/api/2/issue/{issue-number}/transitions
        public static let core = Project(prefix: "UA", transactionIds: .default)
        public static let v3 = Project(prefix: "MON", transactionIds: .init(done: 321, awaitingBuild: 281, peerReview: 131, inProgress: 121))
        public static let nhs = Project(prefix: "NHS", transactionIds: .default)
        public static let avalon = Project(prefix: "AV", transactionIds: .default)
        public static let consultations = Project(prefix: "CE", transactionIds: .init(done: 151, awaitingBuild: 161, peerReview: 171, inProgress: 121))
        public static let prescriptions = Project(prefix: "PRSCR", transactionIds: .init(done: 61, awaitingBuild: 61, peerReview: 81, inProgress: 21))
        public static let telus = Project(prefix: "TEL", transactionIds: .init(done: 31, awaitingBuild: 41, peerReview: 51, inProgress: 21))
        public static let consumer = Project(prefix: "CNSMR", transactionIds: .init(done: 201, awaitingBuild: 31, peerReview: 21, inProgress: 91))
        public static let sdk = Project(prefix: "SDK", transactionIds: .init(done: 41, awaitingBuild: 31, peerReview: 21, inProgress: 11))
        public static let triage = Project(prefix: "GW", transactionIds: .init(done: 61, awaitingBuild: 51, peerReview: 91, inProgress: 21))
        public static let monitor = Project(prefix: "MS", transactionIds: .init(done: 41, awaitingBuild: 141, peerReview: 101, inProgress: 31))
        public static let testKits = Project(prefix: "TK", transactionIds: .init(done: 201, awaitingBuild: 231, peerReview: 191, inProgress: 181))
        public static let platform = Project(prefix: "IOSP", transactionIds: .init(done: 201, awaitingBuild: 31, peerReview: 21, inProgress: 91))
        public static let coreUS = Project(prefix: "COREUS", transactionIds: .init(done: 31, awaitingBuild: 51, peerReview: 51, inProgress: 21))
        public static let realTimeMatching = Project(prefix: "RM", transactionIds: .init(done: 61, awaitingBuild: 111, peerReview: 81, inProgress: 21))
        public static let appointments1 = Project(prefix: "APPTS", transactionIds: .init(done: 31, awaitingBuild: 141, peerReview: 81, inProgress: 21))
        public static let usDelivery = Project(prefix: "USD", transactionIds: .init(done: 41, awaitingBuild: 141, peerReview: 91, inProgress: 81))
        public static let paymentsEligibility = Project(prefix: "PAYE", transactionIds: .init(done: 31, awaitingBuild: 111, peerReview: 81, inProgress: 21))
        public static let partnership = Project(prefix: "PDT", transactionIds: .init(done: 31, awaitingBuild: 151, peerReview: 151, inProgress: 21))
    }
}
