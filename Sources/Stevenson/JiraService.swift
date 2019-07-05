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
                    self.content = [DocContent.paragraph(content: [Text(text)])]
                }
            }

            public struct DocContent: Content {
                let type: String
                let attrs: [String: Int]?
                let content: [Text]?

                public static func heading(level: Int, title: String) -> DocContent {
                    return DocContent(type: "heading", attrs: ["level": level], content: [Text(title)])
                }

                public static func paragraph(content: [Text]) -> DocContent {
                    return DocContent(type: "paragraph", attrs: nil, content: content)
                }
            }

            public struct Text: Content {
                let type: String
                let text: String?
                init(type: String, text: String?) {
                    self.type = type
                    self.text = text
                }
                public init(_ text: String) {
                    self.type = "text"
                    self.text = text
                }
                public static func hardbreak() -> Text {
                    return Text(type: "hardbreak", text: nil)
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
