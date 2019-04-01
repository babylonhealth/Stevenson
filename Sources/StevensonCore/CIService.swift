import Vapor

public struct BuildResponse: Content {
    public let branch: String
    public let buildURL: String

    enum CodingKeys: String, CodingKey {
        case branch
        case buildURL = "build_url"
    }
}

public protocol CIService {
    func run(
        command: Command,
        branch: String?,
        on request: Request
    ) throws -> Future<BuildResponse>
}
