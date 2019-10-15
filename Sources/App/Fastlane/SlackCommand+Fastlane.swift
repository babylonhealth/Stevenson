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
                        command: "/fastlane",
                        text: "testflight target:\(metadata.text)",
                        responseURL: metadata.responseURL
                    ),
                    branch: releaseBranchName(from: metadata),
                    ci: ci,
                    on: container
                )
        })
    }

    static let appcenter = { (ci: CircleCIService) in
        SlackCommand(
            name: "appcenter",
            help: """
            Makes a new beta build for AppCenter. Shorthand for `/fastlane appcenter`.

            Parameters:
            - name of the target (as in the project)
            - `branch`: name of the branch to run the lane on. Default is `\(RepoMapping.ios.repository.baseBranch)`

            Example:
            `/appcenter Babylon \(Option.branch.value):develop`
            """,
            allowedChannels: ["ios-build"],
            run: { metadata, container in
                try runLane(
                    metadata: SlackCommandMetadata(
                        token: metadata.token,
                        channelName: metadata.channelName,
                        command: "/fastlane",
                        text: "appcenter target:\(metadata.text)",
                        responseURL: metadata.responseURL
                    ),
                    ci: ci,
                    on: container
                )
        })
    }

    static func runPipeline(
        metadata: SlackCommandMetadata,
        branch: String? = nil,
        ci: CircleCIService,
        on container: Container
    ) throws -> Future<SlackResponse> {
        let pipeline = String(metadata.textComponents[0])
        let optionsKeysValues = metadata.textComponents.dropFirst()
            .compactMap { (component: String.SubSequence) -> (String, CircleCIService.PipelineRequest.Parameter)? in
                let components = component.split(separator: ":")
                if components.count == 1 {
                    return (String(components[0]), .bool(true))
                } else if components.count == 2 {
                    return (String(components[0]), .string(String(components[1])))
                } else {
                    return nil
                }
        }
        var parameters = Dictionary(optionsKeysValues, uniquingKeysWith: { $1 })
        parameters["push"] = .bool(false)
        parameters[pipeline] = .bool(true)
        // branch parameter is not needed in parameters and actually results in unexpected parameter error
        parameters["branch"] = nil

        return try run(
            pipeline,
            parameters: parameters,
            metadata: metadata,
            branch: branch,
            ci: ci,
            on: container
        )
    }

    static func runLane(
        metadata: SlackCommandMetadata,
        branch: String? = nil,
        ci: CircleCIService,
        on container: Container
    ) throws -> Future<SlackResponse> {
        let lane = String(metadata.textComponents[0])
        let options = metadata.textComponents.dropFirst().joined(separator: " ")

        let parameters: [String: CircleCIService.PipelineRequest.Parameter] = [
            "push": .bool(false),
            "lane": .string(lane),
            "options": .string(options)
        ]
        return try run(
            lane,
            parameters: parameters,
            metadata: metadata,
            branch: branch,
            ci: ci,
            on: container
        )
    }

    private static func run(
        _ pipelineOrLane: String,
        parameters: [String: CircleCIService.PipelineRequest.Parameter],
        metadata: SlackCommandMetadata,
        branch: String?,
        ci: CircleCIService,
        on container: Container
    ) throws -> Future<SlackResponse> {
        let branch = branch ?? metadata.value(forOption: .branch)

        return try ci
            .pipeline(
                parameters: parameters,
                project: RepoMapping.ios.repository.fullName,
                branch: branch ?? RepoMapping.ios.repository.baseBranch,
                on: container
            )
            .map {
                SlackResponse("""
                    You asked me: `\(metadata.command) \(metadata.text)`.
                    🚀 Triggered `\(pipelineOrLane)` on the `\($0.branch)` branch.
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
