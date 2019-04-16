import Foundation
import Vapor

extension GitHubService {
    public struct Repository {
        public let fullName: String
        public let baseBranch: String
        
        public init(fullName: String, baseBranch: String) {
            self.fullName = fullName
            self.baseBranch = baseBranch
        }
    }
}
