import Vapor

public struct Command {
    public let name: String
    public let arguments: [String: String]
    public let branch: String?

    public init(name: String, arguments: [String: String], branch: String?) {
        self.name = name
        self.arguments = arguments
        self.branch = branch
    }
}

public protocol CommandHandler {
    func command(from request: HTTPRequest) throws -> Command
    func result(from response: String) throws -> HTTPResponse
}
