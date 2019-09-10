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
            run: { metadata, container in
                try runLane(
                    metadata: metadata,
                    ci: ci,
                    on: container
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
            - `branch`: release branch name. Default is `release/<name.lowercase()>/<version>`

            Example:
            `/testflight Babylon \(Option.version.value):3.13.0`
            """,
            allowedChannels: ["ios-build"],
            run: { metadata, container in
                try runLane(
                    metadata: SlackCommandMetadata(
                        token: metadata.token,
                        channelName: metadata.channelName,
                        text: "testflight target:\(metadata.text)",
                        responseURL: metadata.responseURL
                    ),
                    branch: releaseBranchName(from: metadata),
                    ci: ci,
                    on: container
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
            run: { metadata, container in
                try runLane(
                    metadata: SlackCommandMetadata(
                        token: metadata.token,
                        channelName: metadata.channelName,
                        text: "hockeyapp target:\(metadata.text)",
                        responseURL: metadata.responseURL
                    ),
                    ci: ci,
                    on: container
                )
        })
    }

    static func runLane(
        metadata: SlackCommandMetadata,
        branch: String? = nil,
        ci: CircleCIService,
        on container: Container
    ) throws -> Future<SlackResponse> {
        let lane = String(metadata.textComponents[0])
        let options = metadata.textComponents.dropFirst().joined(separator: " ")
        let branch = branch ?? metadata.value(forOption: .branch)

        let parameters = ["FASTLANE": lane, "OPTIONS": options]
        
        return try ci
            .run(
                parameters: parameters,
                project: RepoMapping.ios.repository.fullName,
                branch: branch ?? RepoMapping.ios.repository.baseBranch,
                on: container
            )
            .map {
                SlackResponse("""
                    You asked me: `\(metadata.text)`.
                    🚀 Triggered `\(lane)` on the `\($0.branch)` branch.
                    \($0.buildURL)
                    """,
                    visibility: .channel
                )
            }
            .replyLater(
                withImmediateResponse: SlackResponse("👍", visibility: .channel),
                responseURL: metadata.responseURL,
                on: container
            )
    }

}

extension SlackCommand {
    private static func releaseBranchName(from metadata: SlackCommandMetadata) -> String? {
        if let branchOption = metadata.value(forOption: .branch) {
            return branchOption
        } else if let app = metadata.textComponents.first, let version = metadata.value(forOption: .version) {
            return  "release/\(app.lowercased())/\(version)"
        } else {
            return nil
        }
    }
}
