import Vapor
import Stevenson

extension JiraService {
    static func makeCRPIssue(
        jiraBaseURL: URL,
        crpConfig: RepoMapping.CRP,
        release: GitHubService.Release,
        changelog: FieldType.TextArea.Document
    ) -> CRPIssue {
        // [CNSMR-1319] TODO: Use a config file to parametrise accountable person
        let isTelus = release.appName.caseInsensitiveCompare("Telus") == .orderedSame
        let accountablePerson = isTelus ? "ryan.covill" : "andreea.papillon"
        let changelog = changelog
        let fields = CRPIssueFields(
            jiraBaseURL: jiraBaseURL,
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
        let jiraReleaseURL: String
        let githubReleaseURL: String
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
            case jiraReleaseURL = "customfield_12540"
            case githubReleaseURL = "customfield_12541"
            case testing = "customfield_11512"
            case accountablePerson = "customfield_11505"
            case infoSecChecked = "customfield_12527"
        }

        // MARK: Inits

        init(
            jiraBaseURL: URL,
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
            self.jiraReleaseURL = "\(jiraBaseURL)/secure/Dashboard.jspa?selectPageId=15452"
            self.githubReleaseURL = "https://github.com/\(release.repository.fullName)/releases/tag/\(release.appName)/\(release.version)"
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
    /// - Returns: The Jira Document structure ready to be inserted in a JIRA TextArea field
    static func document(from changelog: [ChangelogSection], jiraBaseURL: URL) -> FieldType.TextArea.Document {
        // Transform CHANGELOG entries into JIRA Document field
        typealias DocContent = FieldType.TextArea.DocContent

        let content = changelog
            .flatMap { (section: ChangelogSection) -> [DocContent] in
                let header = section.board.map { "\($0) tickets" } ?? "Other"
                let listItems = section.commits.map {
                    formatMessageLine($0.message, jiraBaseURL: jiraBaseURL)
                }

                return [
                    DocContent.heading(level: 3, title: header),
                    DocContent.bulletList(items: listItems)
                ]
        }
        return FieldType.TextArea.Document(content: content)
    }

    /// Extract tickets from a commit message to create a mix of `.text` and `.inlineCard` content
    ///
    /// - Parameter string: The commit message / string to extract tickets from
    /// - Returns: An array of `.text` and `.inlineCard` elements corresponding to the parsed string
    static func formatMessageLine(_ string: String, jiraBaseURL: URL) -> FieldType.TextArea.ListItem {
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
        return .init(content: result)
    }
}

// MARK: support for "Fixed Version"

extension JiraService {
    struct FixedVersionReport: CustomStringConvertible {
        let messages: [String]
        init(_ message: String = "") {
            self.messages = message.isEmpty ? [] : [message]
        }
        init(reports: [FixedVersionReport]) {
            self.messages = reports.flatMap { $0.messages }
        }
        var description: String {
            return messages.map({ " - \($0)" }).joined(separator: "\n")
        }
    }

    func createAndSetFixedVersions(changelogSections: [ChangelogSection], versionName: String, on container: Container) throws -> Future<FixedVersionReport> {
        return try changelogSections
            .compactMap { $0.tickets() }
            .map { (project: (key: String, tickets: [String])) -> Future<FixedVersionReport> in
                guard let projectID = self.knownProjects[project.key] else {
                    return container.future(
                        FixedVersionReport("Project \(project.key) is not part of our whitelist for creating JIRA versions")
                    )
                }
                let version = JiraService.Version(
                    projectId: projectID,
                    description: versionName,
                    name: versionName,
                    startDate: Date()
                )
                return try self.createVersion(version, on: container)
                    .flatMap { try self.batchSetFixedVersions($0, tickets: project.tickets, on: container) }
                    .mapIfError { FixedVersionReport("Error creating JIRA version in board \(project.key) - \($0)") }
            }
            .map(to: FixedVersionReport.self, on: container, FixedVersionReport.init)
    }

    func batchSetFixedVersions(_ version: JiraService.Version, tickets: [String], on container: Container) throws -> Future<FixedVersionReport> {
        return try tickets
            .map { (ticket: String) -> Future<FixedVersionReport> in
                try self.setFixedVersion(version, for: ticket, on: container)
                    .map { _ in FixedVersionReport() }
                    .mapIfError { FixedVersionReport("Error setting FixedVersion for \(ticket) - \($0)") }
            }
            .map(to: FixedVersionReport.self, on: container, FixedVersionReport.init)
    }
}
