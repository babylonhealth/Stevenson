import Vapor
import Stevenson

extension JiraService {
    static func makeCRPIssue(
        crpConfig: RepoMapping.CRP,
        release: GitHubService.Release,
        changelog: FieldType.TextArea.Document
    ) -> CRPIssue {
        // [CNSMR-1319] TODO: Use a config file to parametrise accountable person
        let isTelus = release.appName.caseInsensitiveCompare("Telus") == .orderedSame
        let accountablePerson = isTelus ? "ryan.covill" : "andreea.papillon"
        let changelog = changelog
        let fields = CRPIssueFields(
            summary: crpConfig.jiraSummary(release),
            environments: [crpConfig.environment],
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

        var project = FieldType.ObjectID(id: "13402") // CRP Project
        var issueType = FieldType.ObjectID(id: "11439") // "CRP: Code Change Request"
        var summary: String
        var changelog: FieldType.TextArea.Document
        var environments: [Environment]
        var businessImpact: FieldType.TextArea.Document
//        let jiraReleaseURL: String
//        let githubReleaseURL: String
        var testing: FieldType.TextArea.Document
        var accountablePerson: FieldType.User
        var infoSecChecked: InfoSecStatus

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
    func document(from changelog: [ChangelogSection]) -> FieldType.TextArea.Document {
        return JiraService.document(from: changelog, jiraBaseURL: self.baseURL)
    }

    /// Transform a list of ChangelogSection into a 'Document' field for the JIRA API
    ///
    /// - Parameter changelog: The list of sections to format
    /// - Returns: The Jira Document structure ready to be inserted in a JIRA TextAre field
    static func document(from changelog: [ChangelogSection], jiraBaseURL: URL) -> FieldType.TextArea.Document {
        // Transform CHANGELOG entries into JIRA Document field
        typealias DocContent = FieldType.TextArea.DocContent

        let content: [DocContent] = changelog
            .flatMap { (section: ChangelogSection) -> [DocContent] in
                let header = section.board.map { "\($0) tickets" } ?? "Other"
                let lines: [DocContent] = section.commits.flatMap {
                    formatMessageLine($0.message, jiraBaseURL: jiraBaseURL)
                }

                return [
                    DocContent.heading(level: 3, title: header),
                    DocContent.paragraph(lines)
                ]
        }
        return FieldType.TextArea.Document(content: content)
    }

    /// Extract tickets from a commit message to create a mix of `.text` and `.inlineCard` content
    ///
    /// - Parameter string: The commit message / string to extract tickets from
    /// - Returns: An array of `.text` and `.inlineCard` elements corresponding to the parsed string
    static func formatMessageLine(_ string: String, jiraBaseURL: URL) -> [FieldType.TextArea.DocContent] {
        let fullRange = NSRange(string.startIndex..<string.endIndex, in: string)
        let matches = TicketID.regex.matches(in: string, options: [], range: fullRange)

        var result: [FieldType.TextArea.DocContent] = []
        var lastIndex = string.startIndex
        for match in matches {
            guard
                let matchRange = Range(match.range(at: 0), in: string),
                let ticketRange = Range(match.range(at: 1), in: string)
                else { continue }
            let beforeText = String(string[lastIndex..<matchRange.lowerBound])
            if !beforeText.isEmpty {
                result.append(.text(beforeText))
            }
            let ticketText = String(string[ticketRange])
            result.append(.inlineCard(baseURL: jiraBaseURL, ticketKey: ticketText))
            lastIndex = matchRange.upperBound
        }
        let endText = String(string[lastIndex..<string.endIndex])
        if !endText.isEmpty {
            result.append(.text(endText))
        }
        result.append(.hardbreak())
        return result
    }
}
