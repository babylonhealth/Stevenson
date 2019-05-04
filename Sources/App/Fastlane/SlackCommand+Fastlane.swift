import Foundation
import Vapor
import Stevenson

extension SlackCommand {
    static let fastlane = { (ci: CircleCIService) in
        SlackCommand(
            name: "fastlane",
            help: """
            Invokes specified lane on specified branch.
            Provide options the same way as when invoking lane locally.

            Parameters:
            - name of the lane to run
            - list of lane options in the fastlane format (e.g. `device:iPhone5s`)
            - `branch`: name of the branch to run the lane on. Default is `\(RepoMapping.ios.repository.baseBranch)`

            Example:
            `/fastlane test_babylon \(Option.branch.value):develop`
            """,
            allowedChannels: ["ios-build"],
            run: { metadata, request in
                try runLane(
                    metadata: metadata,
                    ci: ci,
                    request: request
                )
        })
    }

    static let testflight = { (ci: CircleCIService) in
        SlackCommand(
            name: "testflight",
            help: """
            Makes a new release candidate for Testflight. Shorthand for `/fastlane testflight`.

            Parameters:
            - name of the target (as in the project)
            - `version`: version of the app
            - `branch`: release branch name. Default is `release/<version>`

            Example:
            `/testflight Babylon \(Option.version.value):3.13.0`
            """,
            allowedChannels: ["ios-build"],
            run: { metadata, request in
                try runLane(
                    metadata: SlackCommandMetadata(
                        token: metadata.token,
                        channelName: metadata.channelName,
                        text: "testflight target:\(metadata.text)",
                        responseURL: metadata.responseURL
                    ),
                    branch: metadata.value(forOption: Option.version).map { "release/\($0)" },
                    ci: ci,
                    request: request
                )
        })
    }

    static let hockeyapp = { (ci: CircleCIService) in
        SlackCommand(
            name: "hockeyapp",
            help: """
            Makes a new beta build for HockeyApp. Shorthand for `/fastlane hockeyapp`.

            Parameters:
            - name of the target (as in the project)
            - `branch`: name of the branch to run the lane on. Default is `\(RepoMapping.ios.repository.baseBranch)`

            Example:
            `/hockeyapp Babylon \(Option.branch.value):develop`
            """,
            allowedChannels: ["ios-build"],
            run: { metadata, request in
                try runLane(
                    metadata: SlackCommandMetadata(
                        token: metadata.token,
                        channelName: metadata.channelName,
                        text: "hockeyapp target:\(metadata.text)",
                        responseURL: metadata.responseURL
                    ),
                    ci: ci,
                    request: request
                )
        })
    }

    private static func runLane(
        metadata: SlackCommandMetadata,
        branch: String? = nil,
        ci: CircleCIService,
        request: Request
    ) throws -> Future<SlackResponse> {
        let components = metadata.text.components(separatedBy: " ")
        let lane = components[0]
        let options = components.dropFirst().joined(separator: " ")
        let branch = branch ?? metadata.value(forOption: Option.branch)

        let args = ["FASTLANE": lane, "OPTIONS": options]
        let command = Command(name: lane, arguments: args)

        return try ci
            .run(
                command: command,
                project: RepoMapping.ios.repository.fullName,
                branch: branch ?? RepoMapping.ios.repository.baseBranch,
                request: request
            )
            .map {
                SlackResponse("""
                    🚀 Triggered `\(command.name)` on the `\($0.branch)` branch.
                    \($0.buildURL)
                    """,
                    visibility: .channel
                )
            }.replyLater(
                withImmediateResponse: SlackResponse("👍"),
                responseURL: metadata.responseURL,
                request: request
        )
    }

}
