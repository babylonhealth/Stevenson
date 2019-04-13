import Foundation
import Vapor

extension GitHubService {
    public struct Release {
        public let repository: Repository
        public let branch: String
        public let appName: String?
        public let version: String

        /// - Parameters:
        ///   - repository: the GHRepo this release is for, ios or android
        ///   - branch: The GIT branch name, typically of the form `release/1.2.3` or `release/1.2.3-nhs111`
        /// - Throws: SlackService.Error
        public init(repository: Repository, branchName: String) throws {
            self.repository = repository
            self.branch = branchName
            let branchComponents = branch.components(separatedBy: "/")
            guard branchComponents.count > 1, ["release", "hotfix"].contains(branchComponents[0]) else {
                throw SlackService.Error.invalidParameter(key: "branch", value: branch, expected: "release or hotfix branch")
            }
            let versionComps = branchComponents[1].components(separatedBy: "-")
            self.version = versionComps[0]
            self.appName = versionComps.count > 1 ? versionComps[1] : nil
        }
    }
}
