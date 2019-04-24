import Foundation
import Vapor
import Stevenson

extension SlackCommand {
    enum Option {
        static let branch = "branch"
        static let repo = "repo"
    }

    static func branch(fromOptions options: [String]) -> String? {
        let branchOptionPrefix = Option.branch + ":"
        let branch = options.dropFirst()
            .first { $0.hasPrefix(branchOptionPrefix) }?
            .dropFirst(branchOptionPrefix.count)
        return branch.map(String.init)
    }
}
