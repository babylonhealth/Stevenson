import Foundation
import StevensonCore
import Vapor

enum Commands {
    static let fastlane = SlackCommand(
        name: "fastlane",
        help: """
        Invokes specified lane on specified branch (or develop if not specified).
        Provide options the same way as when invoking lane locally.

        Example:
        `/fastlane test_babylon \(CircleCIService.branchArgument):develop`
        """,
        token: Environment.get("SLACK_TOKEN_FASTLANE")!,
        parse: { content in
            let components = content.text.components(separatedBy: " ")
            let lane = components[0]
            let options = components.dropFirst().joined(separator: " ")
            var args = ["FASTLANE": lane, "OPTIONS": options]

            if let branch = Commands.branch(fromOptions: components) {
                args[CircleCIService.branchArgument] = branch
            }

            return Command(name: lane, arguments: args)
    })

    private static func branch(fromOptions options: [String]) -> String? {
        let branchArgument = CircleCIService.branchArgument
        let branchOptionPrefix = "\(branchArgument):"
        let branch = options.dropFirst()
            .first { $0.hasPrefix(branchOptionPrefix) }?
            .dropFirst(branchOptionPrefix.count)
        return branch.map(String.init)
    }
}
