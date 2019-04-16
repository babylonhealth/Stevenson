import Foundation
import Vapor

extension GitHubService {
    public struct Release {
        public let repository: Repository
        public let branch: String
        public let appName: String?
        public let version: String

        public init(repository: Repository, branch: String, appName: String?, version: String) {
            self.repository = repository
            self.branch = branch
            self.appName = appName
            self.version = version
        }
    }
}
