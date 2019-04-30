import Foundation
import Vapor

public struct GitHubService: Service {
    public let baseURL = URL(string: "https://api.github.com:443")!
    public let headers: HTTPHeaders

    public init(username: String, token: String) {
        var headers = HTTPHeaders()
        headers.add(name: HTTPHeaderName.accept, value: MediaType.json.description)
        headers.basicAuthorization = BasicAuthorization(username: username, password: token)
        self.headers = headers
    }
}
