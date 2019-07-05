import Vapor
import Stevenson

extension JiraService {
    func makeCRPIssue(
        repoMapping: RepoMapping,
        release: GitHubService.Release,
        changelog: FieldType.TextArea.Document
    ) -> CRPIssue {
        // [CNSMR-1319] TODO: Use a config file to parametrise accountable person
        let isTelus = release.appName.caseInsensitiveCompare("Telus") == .orderedSame
        let accountablePerson = isTelus ? "ryan.covill" : "andreea.papillon"
        // Remove brackets around JIRA ticket names so that it's recognized by JIRA as a ticket reference
        // eg replace "[CNSMR-123] Do this" with "CNSMR-123 Do this"
        let changelog = changelog
        let fields = CRPIssueFields(
            summary: repoMapping.crp.jiraSummary(release),
            environments: [repoMapping.crp.environment],
            release: release,
            changelog: changelog,
            accountablePersonName: accountablePerson
        )
        return CRPIssue(fields: fields)
    }
}


// MARK: - Define a CRP Issue
extension JiraService {

    /// A CRPIssue is a Jira issue specific to our CRP Board (aka Releases Plan Board)
    /// CRP means "Change Request Process" and is part of our SSDLC to track upcoming releases
    typealias CRPIssue = Issue<CRPIssueFields>

    struct CRPIssueFields: JiraIssueFields {

        // MARK: Custom Field Types specific to CRP board

        struct Environment: Content {
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

        let project = FieldType.ObjectID(id: "13402") // CRP Project
        let issueType = FieldType.ObjectID(id: "11439") // "CRP: Code Change Request"
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

        init(
            summary: String,
            environments: [Environment],
            release: GitHubService.Release,
            changelog: FieldType.TextArea.Document,
            accountablePersonName: String
        ) {
            self.summary = summary
            self.changelog = changelog
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



extension JiraService {
    /// Represents a reference to a JIRA ticket, in the form [XXX-123]
    struct TicketID: CustomStringConvertible {
        /// The board code, e.g. `NRX`, `AV`, `CNSMR`...
        let board: String
        /// The ticket number (just the part after the dash), e.g. `123`
        let number: String

        /// The full ticket name (the field 'key' in JIRA API), e.g. `CNSMR-123`
        var key: String {
            return "\(board)-\(number)"
        }

        var description: String {
            return key
        }

        init(board: String, number: String) {
            self.board = board.uppercased()
            self.number = number
        }

        /// Extract a Ticket reference from a commit message
        ///
        /// - Parameter message: The commit message to extract the ticket reference from
        init?(from message: String) {
            let fullRange = NSRange(message.startIndex..<message.endIndex, in: message)
            let match = TicketID.regex.firstMatch(in: message, options: [], range: fullRange)
            guard
                let board = TicketID.text(for: match, at: 1, in: message),
                let number = TicketID.text(for: match, at: 2, in: message)
                else { return nil }
            self.init(board: board, number: number)
        }

        private static let regex = try! NSRegularExpression(pattern: #"\b([A-Za-z]*)-([0-9]*)\b"#, options: [])

        private static func text(for match: NSTextCheckingResult?, at index: Int, in text: String) -> String? {
            return match
                .map { $0.range(at: index) }
                .flatMap { Range($0, in: text) }
                .map { String(text[$0]) }
        }
    }
}


extension JiraService {
    /// Transform a list of ChangelogSection into a 'Document' field for the JIRA API
    ///
    /// - Parameter changelog: The list of sections to format
    /// - Returns: The Jira Document structure ready to be inserted in a JIRA TextAre field
    static func document(from changelog: [ChangelogSection]) -> FieldType.TextArea.Document {
        // Transform CHANGELOG entries into JIRA Document field
        typealias DocContent = FieldType.TextArea.DocContent
        typealias Text = FieldType.TextArea.Text

        let content: [DocContent] = changelog
            .flatMap { (section: ChangelogSection) -> [DocContent] in
                let header = section.board.map { "\($0) tickets" } ?? "Other"
                let lines: [Text] = section.commits
                    .map { stripTicketBrackets($0.message) }
                    .flatMap { [Text($0), Text.hardbreak()] }
                    .dropLast()

                return [
                    DocContent.heading(level: 3, title: header),
                    DocContent.paragraph(content: lines)
                ]
        }
        return FieldType.TextArea.Document(content: content)
    }

    /// Strips square brackets around JIRA ticket references, so that the JIRA UI detects them as links to tickets
    private static func stripTicketBrackets(_ string: String) -> String {
        return string.replacingOccurrences(
            of: "\\[([A-Z]+-[0-9]+)\\]",
            with: "$1",
            options: [.regularExpression],
            range: nil
        )
    }
}
