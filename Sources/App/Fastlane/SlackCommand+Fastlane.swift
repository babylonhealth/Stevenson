import Foundation
import Vapor
import Stevenson

extension SlackCommand {
    static let fastlane = { (ci: CircleCIService) in
        SlackCommand(
            name: "fastlane",
            help: """
            Invokes specified lane on specified branch (or develop if not specified).
            Provide options the same way as when invoking lane locally.

            Parameters:
            - name of the lane to run
            - list of lane options in fastlane format (e.g. `device:iPhone5s`)
            - branch: name of the branch to run the lane on

            Example:
            `/fastlane test_babylon \(Option.branch):develop`
            """,
            allowedChannels: ["ios-build"],
            run: { metadata, request in
                let components = metadata.text.components(separatedBy: " ")
                let lane = components[0]
                let options = components.dropFirst().joined(separator: " ")
                let args = ["FASTLANE": lane, "OPTIONS": options]
                let command = Command(name: lane, arguments: args)
                let branch = SlackCommand.branch(fromOptions: components)

                return try ci
                    .run(
                        command: command,
                        project: RepoMapping.ios.repository.fullName,
                        branch: branch ?? RepoMapping.ios.repository.baseBranch,
                        request: request
                    )
                    .map {
                        SlackResponse("""
                            Triggered `\(command.name)` on the `\($0.branch)` branch.
                            \($0.buildURL)
                            """
                        )
                    }.replyLater(
                        withImmediateResponse: SlackResponse("👍", visibility: .user),
                        responseURL: metadata.responseURL,
                        request: request
                )
        })
    }
}
