import Stevenson
import Vapor

public extension JiraService {

    /// A CRPIssue is a Jira issue specific to our CRP Board (aka Releases Plan Board)
    /// CRP means "Change Request Process" and is part of our SSDLC to track upcoming releases
    public typealias CRPIssue = Issue<CRPIssueFields>

    public struct CRPIssueFields: JiraIssueFields {

        // MARK: Custom Field Types specific to CRP board

        public struct Environment: Content {
            let id: String

            static let playStore = Environment(id: "12394")
            static let appStore = Environment(id: "12395")
            static let notApplicable = Environment(id: "12396")
        }

        struct InfoSecStatus: Content {
            let id: String
            static let yes = InfoSecStatus(id: "11942")
            static let no = InfoSecStatus(id: "11941")
        }

        // MARK: Fields

        public let project = FieldType.ObjectID(id: "13402") // CRP Project
        public let issueType = FieldType.ObjectID(id: "11439") // "CRP: Code Change Request"
        let summary: String
        var changelog: FieldType.TextArea.Document
        let environments: [Environment]
        var businessImpact: FieldType.TextArea.Document
//        let jiraReleaseURL: String
//        let githubReleaseURL: String
        var testing: FieldType.TextArea.Document
        var accountablePerson: FieldType.User
        let infoSecChecked: InfoSecStatus

        // MARK: Content keys

        enum CodingKeys: String, CodingKey {
            case project = "project"
            case issueType = "issuetype"
            case summary = "summary"
            case changelog = "customfield_12537"
            case environments = "customfield_12592"
            case businessImpact = "customfield_12538"
            // [CNSMR-1318] TODO: Find a way to send those "URL" fields as well.
            // (JIRA API seems to expect an 'object' when sending fields of type "URL")
//            case jiraReleaseURL = "customfield_12540"
//            case githubReleaseURL = "customfield_12541"
            case testing = "customfield_11512"
            case accountablePerson = "customfield_11505"
            case infoSecChecked = "customfield_12527"
        }

        // MARK: Inits

        public init(
            summary: String,
            environments: [Environment],
            release: GitHubService.Release,
            changelog: String,
            accountablePersonName: String
        ) {
            self.summary = summary
            self.changelog = FieldType.TextArea.Document(text: changelog)
            self.environments = environments
            self.businessImpact = FieldType.TextArea.Document(text: "TBD")
//            self.jiraReleaseURL = "https://\(jira.host)/secure/Dashboard.jspa?selectPageId=15452"
//            self.githubReleaseURL = "https://github.com/\(release.repository.fullName)/releases/tag/\(release.version)"
            self.testing = FieldType.TextArea.Document(text: "TBD")
            self.accountablePerson = FieldType.User(name: accountablePersonName)
            self.infoSecChecked = .no
        }
    }
}
