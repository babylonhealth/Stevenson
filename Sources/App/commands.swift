import Foundation
import Vapor
import StevensonCore

extension SlackCommand {
    static let fastlane = { (ci: CIService) in
        SlackCommand(
            name: "fastlane",
            help: """
            Invokes specified lane on specified branch (or develop if not specified).
            Provide options the same way as when invoking lane locally.

            Example:
            `/fastlane test_babylon \(branchOptionPrefix)develop`
            """,
            token: Environment.get("SLACK_TOKEN_FASTLANE")!) { metadata, request in
                let components = metadata.text.components(separatedBy: " ")
                let lane = components[0]
                let options = components.dropFirst().joined(separator: " ")
                let args = ["FASTLANE": lane, "OPTIONS": options]
                let command = Command(name: lane, arguments: args)
                let branch = SlackCommand.branch(fromOptions: components)

                return try ci
                    .run(command: command, branch: branch, on: request)
                    .map {
                        SlackResponse("""
                            Triggered `\(command.name)` on the `\($0.branch)` branch.
                            \($0.buildURL)
                            """
                        )
                }
        }
    }

    private static let branchOptionPrefix = "branch:"

    private static func branch(fromOptions options: [String]) -> String? {
        let branch = options.dropFirst()
            .first { $0.hasPrefix(branchOptionPrefix) }?
            .dropFirst(branchOptionPrefix.count)
        return branch.map(String.init)
    }
}
