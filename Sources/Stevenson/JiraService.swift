import Foundation
import Vapor

public struct JiraService {
    public let baseURL: URL
    private let headers: HTTPHeaders

    public init(baseURL: URL, username: String, password: String) {
        self.baseURL = baseURL

        let base64Auth = Data("\(username):\(password)".utf8).base64EncodedString(options: [])
        self.headers = [
            "Authorization": "Basic \(base64Auth)",
            "Content-Type": "application/json",
            "Accept": "application/json"
        ]
    }
}

// MARK: Ticket ID

extension JiraService {
    /// Represents a reference to a JIRA ticket, in the form [XXX-123]
    public struct TicketID: CustomStringConvertible {
        /// The board code, e.g. `NRX`, `AV`, `CNSMR`...
        public let board: String
        /// The ticket number (just the part after the dash), e.g. `123`
        public let number: String

        /// The full ticket name (the field 'key' in JIRA API), e.g. `CNSMR-123`
        public var key: String {
            return "\(board)-\(number)"
        }

        public var description: String {
            return key
        }

        public init(board: String, number: String) {
            self.board = board.uppercased()
            self.number = number
        }

        /// Extract a Ticket reference from a commit message
        ///
        /// - Parameter message: The commit message to extract the ticket reference from
        public init?(from message: String) {
            let fullRange = NSRange(message.startIndex..<message.endIndex, in: message)
            let match = JiraService.TicketID.regex.firstMatch(in: message, options: [], range: fullRange)
            guard
                let board = JiraService.TicketID.text(for: match, at: 2, in: message),
                let number = JiraService.TicketID.text(for: match, at: 3, in: message)
                else { return nil }
            self.init(board: board, number: number)
        }

        public static let regex = try! NSRegularExpression(pattern: #"\[?\b(([A-Za-z]*)-([0-9]*))\b\]?"#, options: [])

        private static func text(for match: NSTextCheckingResult?, at index: Int, in text: String) -> String? {
            return match
                .map { $0.range(at: index) }
                .flatMap { Range($0, in: text) }
                .map { String(text[$0]) }
        }
    }
}

// MARK: Issue creation

public protocol JiraIssueFields: Content {
    var project: JiraService.FieldType.ObjectID { get }
    var issueType: JiraService.FieldType.ObjectID { get }
}

extension JiraService {
    public struct Issue<Fields: JiraIssueFields>: Content {
        let fields: Fields
        public init(fields: Fields) {
            self.fields = fields
        }
    }

    public struct CreatedIssue: Content {
        public let id: String
        public let key: String
        public let url: String
        enum CodingKeys: String, CodingKey {
            case id
            case key
            case url = "self"
        }
    }

    public func create<Fields>(issue: Issue<Fields>, on container: Container) throws -> Future<CreatedIssue> {
        let fullURL = URL(string: "/rest/api/3/issue", relativeTo: baseURL)!
        return try container.client()
            .post(fullURL, headers: self.headers) {
                try $0.content.encode(issue)
            }
            .catchError(.capture())
            .flatMap {
                try $0.content.decode(CreatedIssue.self)
            }
            .catchError(.capture())
    }
}


// MARK: Jira Common Field Types

extension JiraService {
    public enum FieldType {
        public enum TextArea {
            public struct Document: Content {
                let type = "doc"
                let content: [DocContent]
                let version = 1
                public init(content: [DocContent]) {
                    self.content = content
                }
                public init(text: String) {
                    self.content = [DocContent.paragraph([.text(text)])]
                }
            }

            public struct DocContent: Content {
                let type: String
                let attrs: [String: AnyCodable]?
                let content: [DocContent]?
                let text: String?

                fileprivate init(type: String, attrs: [String: Any]? = nil, content: [DocContent]? = nil, text: String? = nil) {
                    self.type = type
                    self.attrs = attrs.map { $0.mapValues { AnyCodable($0) } }
                    self.content = content
                    self.text = text
                }

                public static func heading(level: Int, title: String) -> DocContent {
                    return DocContent(type: "heading", attrs: ["level": level], content: [.text(title)])
                }

                public static func bulletList(items: [ListItem]) -> DocContent {
                    return DocContent(type: "bulletList", content: items.map { $0.content })
                }

                public static func paragraph(_ content: [DocContent]) -> DocContent {
                    return DocContent(type: "paragraph", content: content)
                }

                public static func inlineCard(baseURL: URL, ticketKey: String) -> DocContent {
                    let url = "\(baseURL)/browse/\(ticketKey)#icft=\(ticketKey)"
                    return DocContent(type: "inlineCard", attrs: ["url": url], content: nil)
                }

                public static func text(_ text: String) -> DocContent {
                    return DocContent(type: "text", text: text)
                }

                public static func hardbreak() -> DocContent {
                    return DocContent(type: "hardBreak")
                }
            }

            public struct ListItem {
                let content: DocContent
                public init(content: [DocContent]) {
                    self.content = DocContent(
                        type: "listItem",
                        content: [DocContent.paragraph(content)]
                    )
                }
            }
        }

        public struct ObjectID: Content {
            let id: String
            public init(id: String) {
                self.id = id
            }
        }

        public struct User: Content {
            let name: String
            public init(name: String) {
                self.name = name
            }
        }
    }
}
