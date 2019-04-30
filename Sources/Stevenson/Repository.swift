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

    public struct Reference: Decodable {
        public let sha: String

        enum CodingKeys: CodingKey {
            case object
            case sha
        }

        public init(from decoder: Decoder) throws {
            let container = try decoder
                .container(keyedBy: CodingKeys.self)
                .nestedContainer(keyedBy: CodingKeys.self, forKey: .object)

            self.sha = try container.decode(String.self, forKey: .sha)
        }
    }
}
