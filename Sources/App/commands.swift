import Foundation
import StevensonCore

let fastlane: SlackCommand = (
    help: """
    Invokes specified lane on specified branch (or develop if not specified).
    Provide options the same way as when invoking lane locally.

    Example:
        `/fastlane test_babylon branch:develop`
    """,
    token: ProcessInfo.processInfo.environment["SLACK_TOKEN_FASTLANE"]!,
    parser: { content in
        let components = content.text.components(separatedBy: " ")
        let lane = components[0]
        let options = components.dropFirst().joined(separator: " ")
        let branch = components.dropFirst()
            .first { $0.hasPrefix("branch:") }?
            .dropFirst("branch:".count)

        let args = ["FASTLANE": lane, "OPTIONS": options]
        return Command(name: lane, arguments: args, branch: branch.map(String.init))
})
