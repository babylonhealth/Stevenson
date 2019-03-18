import Foundation
import StevensonCore

let fastlane = SlackCommand(
    name: "fastlane",
    help: """
    Invokes specified lane on specified branch (or develop if not specified).
    Provide options the same way as when invoking lane locally.

    Example:
        `/fastlane test_babylon branch:develop`
    """,
    token: ProcessInfo.processInfo.environment["SLACK_TOKEN_FASTLANE"]!,
    parse: { content in
        let components = content.text.components(separatedBy: " ")
        let lane = components[0]
        let options = components.dropFirst().joined(separator: " ")
        var args = ["FASTLANE": lane, "OPTIONS": options]

        let branchArgument = CircleCIService.branchArgument
        let branch = components.dropFirst()
            .first { $0.hasPrefix("\(branchArgument):") }?
            .dropFirst("\(branchArgument):".count)

        if let branch = branch {
            args[branchArgument] = String(branch)
        }

        return Command(name: lane, arguments: args)
})
