import Foundation
import Vapor
import Stevenson

extension SlackCommand {
    enum Option {
        static let branch = "branch"
        static let repo = "repo"
        static let version = "version"
    }
}

extension SlackCommandMetadata {
    func value(forOption option: String) -> String? {
        let optionPrefix = option + ":"
        let branch = textComponents.dropFirst()
            .first { $0.hasPrefix(optionPrefix) }?
            .dropFirst(optionPrefix.count)
        return branch.map(String.init)
    }
}
